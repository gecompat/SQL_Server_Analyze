USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CheckAnalyseAccess
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Prüft die effektive Analyseklassen- und AD-Gruppenpolicy.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit access und policies.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CheckAnalyseAccess]
      @AnalyseKlasse   varchar(64)    = NULL
    , @NurGesperrte    bit            = 0
    , @ResultSetArt    varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen    bit             = 0
    , @Json             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen  bit             = 1
    , @Hilfe            bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'access',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CheckAnalyseAccess prüft den Framework-Gruppengate für Analyseklassen im aktuellen Login- und Execution-Kontext. Die Procedure führt keine Fachanalyse aus und vergibt keine SQL-Rechte.';
        PRINT N'Quellen: Klassenkatalog, VW_AnalyseAccessCurrent, VW_AnalyseAccessPolicy, sys.login_token und IS_MEMBER. Momentaufnahme gegen SYSUTCDATETIME(); kein Live-AD- oder Objektberechtigungsnachweis.';
        PRINT N'Ohne aktive Policy ist der Gate offen. Sobald global mindestens eine aktive Policy existiert, kann eine geschützte Klasse ohne spezifische oder *-Regel gesperrt sein. Token-Match hat Vorrang vor IS_MEMBER; sonst NO_MATCH.';
        PRINT N'@AnalyseKlasse: varchar(64), Default NULL. Ausgelassen oder NULL wählt alle 31 Klassen. Sonst wird der Wert mit der Katalogspalte unter SQL_Latin1_General_CP1_CS_AS verglichen; es gibt kein LTRIM/RTRIM. Groß-/Kleinschreibung zählt; SQL-Gleichheit kann nachgestellte U+0020 auffüllen. Leer oder nicht passend ergibt INVALID_PARAMETER. Wirkung: auf eine Klasse begrenzen. Zulässige Klassen mit Bedeutung:';
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
        PRINT N'@NurGesperrte: bit, Default 0. 0 liefert alle Accesszeilen; 1 nur Zeilen mit IsAllowed=0. NULL wirkt im SQL-Filter ebenfalls wie 1. Filtert nur Access, nicht Policies. Ausgelassen verwendet 0.';
        PRINT N'@ResultSetArt: varchar(16), Default ''CONSOLE''. Werte: CONSOLE rendert Access und liefert Policies/Warnings zusätzlich; RAW liefert Meta, Access, Policies, Warnings als vier Resultsets; TABLE exportiert nur Access; NONE unterdrückt fachliche Resultsets. Eingabe wird mit LTRIM/RTRIM an äußeren U+0020 entfernt und mit UPPER normalisiert. NULL/sonst ungültig ergibt INVALID_PARAMETER. Ausgelassen = CONSOLE.';
        PRINT N'CONSOLE rendert Access als Ergebnis und zeigt zusätzlich Policy- und Warning-Resultsets. RAW liefert Meta, Access, Policies und Warnings als vier technische Resultsets.';
        PRINT N'TABLE schreibt ausschließlich das benannte access-Resultset mit 12 Accessfeldern in eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte beliebigen Datentyps. Der Preflight prüft das Ziel durch vorübergehendes Hinzufügen und Entfernen einer bit-NULL-Prüfspalte.';
        PRINT N'access-Felder: AnalysisClass varchar(64), AnalysisLevel varchar(16), RequiresGroupGate bit, OriginalLoginName sysname NULL, EffectiveLoginName sysname NULL, IsSysadmin bit NULL, ActivePolicyCount bigint NULL, RelevantPolicyCount bigint NULL, IsAllowed bit, AccessReason varchar(20) NULL, MatchedGroupCount bigint NULL, StatusCode varchar(40).';
        PRINT N'TABLE-Preflight kann vor der Hilfe lokale TempDB-Metadaten per DDL ändern und bei ungültiger Zuordnung mit Fehler 51011/Preflightfehler abbrechen. Kein Max-Zeilen-Parameter.';
        PRINT N'NONE liefert keine fachlichen Resultsets. Statusmeldungen und JSON sind davon unabhängig; @PrintMeldungen=0 unterdrückt weder Hilfe noch JSON.';
        PRINT N'@ResultTablesJson: nvarchar(max), Default NULL. NULL/ausgelassen bedeutet keine Zuordnung. Für TABLE ist ein nichtleeres gültiges JSON-Objekt mit genau dem nach U+0020-Trimmen case-sensitiven Schlüssel "access" und einem nach U+0020-Trimmen nichtleeren JSON-String als Ziel erforderlich; Schlüssel und Ziele müssen eindeutig sein. Zielname: vorhandene lokale #temp-Tabelle, nie ##, höchstens LEN 116, nicht #Monitor* (case-insensitiv); muss leer sein und genau eine beliebig typisierte Seed-Spalte enthalten. Der Preflight fügt vorübergehend eine bit-NULL-Prüfspalte hinzu/entfernt sie wieder; das ist keine Seed-Typvorgabe. U+0020 außen am JSON wird für Objektklammern getrimmt; leere/ungültige JSON-Objekte, falsche Schlüssel/Werttypen, leere Namen, Duplikate, unzulässige Namen, fehlendes/gefülltes/mehrspaltiges Ziel scheitern im Preflight (bei Procedure-Aufruf THROW 51011). Außerhalb TABLE führt jede nichtleere Zuordnung zu THROW 51011.';
        PRINT N'@JsonErzeugen: bit, Default 0. 0/NULL erzeugt kein JSON; 1 erzeugt @Json mit meta sowie access-, policies- und warnings-Arrays. Ausgelassen verwendet 0.';
        PRINT N'@Json: nvarchar(max), Default NULL OUTPUT. Als OUTPUT-Variable binden, um das erzeugte Dokument zu erhalten; bei deaktiviertem JSON bleibt es NULL. Der Eingangswert wird zu Beginn vor TABLE-Preflight und Hilfe verworfen und auf NULL gesetzt. Ausgelassen ist möglich, dann wird kein Wert empfangen.';
        PRINT N'@PrintMeldungen: bit, Default 1. 1 gibt eine zusätzliche Severity-10-Meldung für behandelte Fehler aus; 0 oder NULL unterdrückt nur diese Meldung, nicht Hilfe, Resultsets, Warnings oder JSON. Ausgelassen = 1.';
        PRINT N'@Hilfe: bit, Default 0. 1 druckt die Hilfe und beendet vor der fachlichen Accessauswertung; NULL/0 führt normal aus. Hilfe ist unabhängig von @PrintMeldungen. Bei TABLE liegt der Mapping-Preflight davor und kann TempDB-Metadaten ändern oder mit 51011 abbrechen. @Json ist vorher bereits NULL.';
        PRINT N'Beispiel – Hilfe: EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;';
        PRINT N'Beispiel – Standard: EXEC [monitor].[USP_CheckAnalyseAccess];';
        PRINT N'Beispiel – Klasse und RAW: EXEC [monitor].[USP_CheckAnalyseAccess] @AnalyseKlasse=''PLAN_CACHE_DEEP'', @ResultSetArt=''RAW'';';
        PRINT N'Beispiel – nur gesperrte Klassen: EXEC [monitor].[USP_CheckAnalyseAccess] @NurGesperrte=1, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel – JSON: DECLARE @j nvarchar(max); EXEC [monitor].[USP_CheckAnalyseAccess] @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;';
        PRINT N'Beispiel – NONE: EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt=''NONE'', @JsonErzeugen=1;';
        PRINT N'Beispiel – TABLE: CREATE TABLE #CheckAnalyseAccess_HelpExample (Seed bit NULL);';
        PRINT N'DECLARE @map nvarchar(max)=N''{"access":"#CheckAnalyseAccess_HelpExample"}''; EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt=''TABLE'', @ResultTablesJson=@map; DROP TABLE #CheckAnalyseAccess_HelpExample;';
        RETURN;
    END;

    CREATE TABLE [#CheckAnalyseAccess_Access]
    (
          [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiresGroupGate] bit NOT NULL
        , [OriginalLoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EffectiveLoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSysadmin] bit NULL
        , [ActivePolicyCount] bigint NULL
        , [RelevantPolicyCount] bigint NULL
        , [IsAllowed] bit NOT NULL
        , [AccessReason] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MatchedGroupCount] bigint NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#CheckAnalyseAccess_Policies]
    (
          [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ADGroupName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Priority] int NOT NULL
        , [ValidFromUtc] datetime2(3) NULL
        , [ValidToUtc] datetime2(3) NULL
        , [MatchesLoginToken] bit NOT NULL
        , [MatchesIsMember] bit NOT NULL
        , [Comment] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CheckAnalyseAccess_Warnings]
    (
          [WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [WarningMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
    END;
    ELSE IF @AnalyseKlasse IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
            WHERE [c].[AnalysisClass] = @AnalyseKlasse
        )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Die Analyseklasse ist nicht in monitor.VW_AnalyseClassCatalog definiert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#CheckAnalyseAccess_Access]
        (
              [AnalysisClass], [AnalysisLevel], [RequiresGroupGate]
            , [OriginalLoginName], [EffectiveLoginName], [IsSysadmin]
            , [ActivePolicyCount], [RelevantPolicyCount], [IsAllowed]
            , [AccessReason], [MatchedGroupCount], [StatusCode]
        )
        SELECT
              [a].[AnalysisClass], [a].[AnalysisLevel], [a].[RequiresGroupGate]
            , [a].[OriginalLoginName], [a].[EffectiveLoginName], [a].[IsSysadmin]
            , [a].[ActivePolicyCount], [a].[RelevantPolicyCount], [a].[IsAllowed]
            , [a].[AccessReason], [a].[MatchedGroupCount]
            , CASE WHEN [a].[IsAllowed] = 1 THEN 'AVAILABLE' ELSE 'DENIED_GROUP' END
        FROM [monitor].[VW_AnalyseAccessCurrent] AS [a]
        WHERE (@AnalyseKlasse IS NULL OR [a].[AnalysisClass] = @AnalyseKlasse)
          AND (@NurGesperrte = 0 OR [a].[IsAllowed] = 0);

        ;WITH [ActivePolicy] AS
        (
            SELECT
                  [p].[AnalysisClass], [p].[ADGroupName], [p].[Priority]
                , [p].[ValidFromUtc], [p].[ValidToUtc], [p].[Comment]
            FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
            WHERE [p].[IsEnabled] = 1
              AND ([p].[ValidFromUtc] IS NULL OR [p].[ValidFromUtc] <= SYSUTCDATETIME())
              AND ([p].[ValidToUtc] IS NULL OR [p].[ValidToUtc] > SYSUTCDATETIME())
              AND (@AnalyseKlasse IS NULL OR [p].[AnalysisClass] IN (@AnalyseKlasse, '*'))
        )
        INSERT [#CheckAnalyseAccess_Policies]
        (
              [AnalysisClass], [ADGroupName], [Priority], [ValidFromUtc]
            , [ValidToUtc], [MatchesLoginToken], [MatchesIsMember], [Comment]
        )
        SELECT
              [p].[AnalysisClass], [p].[ADGroupName], [p].[Priority]
            , [p].[ValidFromUtc], [p].[ValidToUtc]
            , CONVERT(bit, CASE WHEN EXISTS
              (
                  SELECT 1
                  FROM [sys].[login_token] AS [lt] WITH (NOLOCK)
                  WHERE [lt].[type] = N'WINDOWS GROUP'
                    AND UPPER(CONVERT(nvarchar(256), [lt].[name])) COLLATE Latin1_General_100_CI_AS
                      = UPPER([p].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
              ) THEN 1 ELSE 0 END)
            , CONVERT(bit, CASE WHEN IS_MEMBER([p].[ADGroupName]) = 1 THEN 1 ELSE 0 END)
            , [p].[Comment]
        FROM [ActivePolicy] AS [p];

        IF EXISTS (SELECT 1 FROM [#CheckAnalyseAccess_Access] WHERE [IsAllowed] = 0)
        BEGIN
            INSERT [#CheckAnalyseAccess_Warnings] VALUES ('DENIED_GROUP', N'Mindestens eine Analyseklasse ist durch die aktuelle Gruppenpolicy gesperrt.');
            SET @StatusCode = 'AVAILABLE_LIMITED';
        END;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'ERROR_HANDLED';
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        INSERT [#CheckAnalyseAccess_Warnings] VALUES (@StatusCode, @ErrorMessage);
    END CATCH;

    IF @PrintMeldungen = 1 AND @ErrorMessage IS NOT NULL
    BEGIN
        DECLARE @PrintMessage nvarchar(2048) = FORMATMESSAGE(N'%s: %s', @StatusCode, @ErrorMessage);
        RAISERROR(N'%s', 10, 1, @PrintMessage) WITH NOWAIT;
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              CAST('2.0' AS varchar(16)) AS [ContractVersion]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , N'monitor.USP_CheckAnalyseAccess' AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT * FROM [#CheckAnalyseAccess_Access] ORDER BY [RequiresGroupGate], [AnalysisLevel], [AnalysisClass];
            SELECT * FROM [#CheckAnalyseAccess_Policies] ORDER BY [Priority], [AnalysisClass], [ADGroupName];
            SELECT * FROM [#CheckAnalyseAccess_Warnings] ORDER BY [WarningCode], [WarningMessage];
        END;
        ELSE
        BEGIN
            SELECT
                  N'Analysezugriff' AS [Ergebnis]
                , [AnalysisClass] AS [Analyseklasse]
                , [AnalysisLevel] AS [Stufe]
                , [IsAllowed] AS [erlaubt]
                , [AccessReason] AS [Begründung]
                , [MatchedGroupCount] AS [passende Gruppen]
                , [StatusCode] AS [Status]
            FROM [#CheckAnalyseAccess_Access]
            ORDER BY [RequiresGroupGate], [AnalysisLevel], [AnalysisClass];

            SELECT
                  N'Aktive Zugriffspolicy' AS [Ergebnis]
                , [AnalysisClass] AS [Analyseklasse]
                , [ADGroupName] AS [AD-Gruppe]
                , [Priority] AS [Priorität]
                , [MatchesLoginToken] AS [im Login-Token]
                , [MatchesIsMember] AS [IS_MEMBER]
                , [Comment] AS [Kommentar]
            FROM [#CheckAnalyseAccess_Policies]
            ORDER BY [Priority], [AnalysisClass], [ADGroupName];

            SELECT N'Warnung' AS [Ergebnis], [WarningCode] AS [Code], [WarningMessage] AS [Meldung]
            FROM [#CheckAnalyseAccess_Warnings]
            ORDER BY [WarningCode], [WarningMessage];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'CheckAnalyseAccess' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @AccessJson nvarchar(max) = (SELECT * FROM [#CheckAnalyseAccess_Access] ORDER BY [RequiresGroupGate], [AnalysisLevel], [AnalysisClass] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @PoliciesJson nvarchar(max) = (SELECT * FROM [#CheckAnalyseAccess_Policies] ORDER BY [Priority], [AnalysisClass], [ADGroupName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) = (SELECT * FROM [#CheckAnalyseAccess_Warnings] ORDER BY [WarningCode], [WarningMessage] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'), N',"access":', COALESCE(@AccessJson, N'[]'), N',"policies":', COALESCE(@PoliciesJson, N'[]'), N',"warnings":', COALESCE(@WarningsJson, N'[]'), N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CheckAnalyseAccess_Access'
            , @ResultLabel=N'CheckAnalyseAccess'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CheckAnalyseAccess_Access'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

