/*
Generated from the canonical standalone Execution Plan Analysis installer.
Do not edit directly; run Build-AdapterInstall.ps1.
*/
USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FrameworkDatabase sysname = N'LabAnalyze';
DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-execution-plan-001';
DECLARE @ContractVersion nvarchar(32) = N'0.1';
DECLARE @Created bit = 0;
DECLARE @Sql nvarchar(max);
DECLARE @ExistingProject nvarchar(128);
DECLARE @ExistingContract nvarchar(32);

IF EXISTS
(
    SELECT 1
    FROM [sys].[databases]
    WHERE [database_id] > 4
      AND [name] NOT IN (N'LabAnalyze', N'AnalyzeAdapterPlan')
)
    THROW 55401, N'ADAPTER_ISOLATION_REQUIRED: Die Instanz enthält eine fremde Benutzerdatenbank.', 1;

IF DB_ID(@FrameworkDatabase) IS NULL
BEGIN
    SET @Sql = N'CREATE DATABASE [LabAnalyze] COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Created = 1;
END;

IF @Created = 1
BEGIN
    EXEC [LabAnalyze].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterProject'
        , @value = @ProjectId;
    EXEC [LabAnalyze].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterContractVersion'
        , @value = @ContractVersion;
END;
ELSE
BEGIN
    SELECT
          @ExistingProject = MAX
          (
              CASE WHEN [name] = N'SQLANALYZE.AdapterProject'
                   THEN CONVERT(nvarchar(128), [value]) END
          )
        , @ExistingContract = MAX
          (
              CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion'
                   THEN CONVERT(nvarchar(32), [value]) END
          )
    FROM [LabAnalyze].[sys].[extended_properties]
    WHERE [class] = 0
      AND [major_id] = 0
      AND [minor_id] = 0;

    IF @ExistingProject <> @ProjectId
       OR @ExistingContract <> @ContractVersion
        THROW 55402, N'ADAPTER_STATE_CONFLICT: LabAnalyze besitzt nicht die erwarteten Adaptermarker.', 1;
END;
GO
USE [LabAnalyze];
GO
/* Generated from canonical Execution Plan Analysis source files. Do not edit directly. */

-- BEGIN SOURCE: Code/00_Setup/000_Preflight_und_Schema.sql
/*
===============================================================================
Objekt/Datei : 000_Preflight_und_Schema.sql
Version      : 2.1.0
Zweck        : Prüft die SQL-Server-Baseline und die Collation der aktuell mit
               USE ausgewählten Installationsdatenbank. Legt das Schema monitor
               idempotent an. Der Platzhalter DeineDatenbank ist vor Ausführung
               durch den tatsächlichen Datenbanknamen zu ersetzen.
Voraussetzung: SQL Server 2019 oder höher; notwendige DDL-Rechte.
Seiteneffekte: Legt ausschließlich das Schema monitor an, sofern es fehlt.
Collation    : Das Framework verwendet durchgängig explizite COLLATE-Klauseln
               und funktioniert auf beliebigen Collations. Getestet und
               garantiert wird ausschließlich SQL_Latin1_General_CP1_CS_AS.
               Bei abweichender Collation wird eine Warnung ausgegeben;
               die Installation wird nicht blockiert.
Änderungen   : 2.1.0 - Collation-Prüfung von Abbruch auf Warnung geändert;
                         das Framework arbeitet collation-agnostisch durch
                         explizite COLLATE-Klauseln in allen Vergleichen.
               2.0.0 - Erstfassung mit harter Collation-Prüfung.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProductMajorVersion int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));
IF @ProductMajorVersion IS NULL OR @ProductMajorVersion < 15
    THROW 50001, N'Das Analyseframework unterstützt mindestens SQL Server 2019 (Major Version 15).', 1;

DECLARE @ExpectedCollation sysname = N'SQL_Latin1_General_CP1_CS_AS';
DECLARE @ServerCollation sysname = CONVERT(sysname, SERVERPROPERTY(N'Collation'));
DECLARE @TempDbCollation sysname = (SELECT [collation_name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [name]=N'tempdb');
DECLARE @TargetDatabaseCollation sysname = (SELECT [collation_name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID());
DECLARE @CollationWarningIssued bit = 0;

IF @ServerCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    RAISERROR(N'[monitor] WARNUNG: Server-Collation ist %s (erwartet: SQL_Latin1_General_CP1_CS_AS). Das Framework verwendet explizite COLLATE-Klauseln und arbeitet grundsätzlich collation-agnostisch. Getestet ist ausschließlich SQL_Latin1_General_CP1_CS_AS; abweichendes Verhalten bei Filterlisten und Objektnamenvergleichen ist möglich.', 10, 1, @ServerCollation) WITH NOWAIT;
    SET @CollationWarningIssued = 1;
END;
IF @TempDbCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    RAISERROR(N'[monitor] WARNUNG: tempdb-Collation ist %s (erwartet: SQL_Latin1_General_CP1_CS_AS). Temporäre Tabellen verwenden explizite COLLATE-Klauseln; Konflikte sind nicht zu erwarten.', 10, 1, @TempDbCollation) WITH NOWAIT;
    SET @CollationWarningIssued = 1;
END;
IF @TargetDatabaseCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    DECLARE @TargetDbName sysname = (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());
    RAISERROR(N'[monitor] WARNUNG: Installationsdatenbank %s hat Collation %s (erwartet: SQL_Latin1_General_CP1_CS_AS). Das Framework funktioniert, jedoch ohne Garantie für ungetestete Collations.', 10, 1, @TargetDbName, @TargetDatabaseCollation) WITH NOWAIT;
    SET @CollationWarningIssued = 1;
END;
IF @CollationWarningIssued = 1
    RAISERROR(N'[monitor] HINWEIS: Die Installation wird fortgesetzt. Das Framework verwendet durchgängig explizite COLLATE SQL_Latin1_General_CP1_CS_AS in Vergleichen, Temp-Tabellen und Rückgabewerten. Bei Problemen prüfen Sie bitte zuerst Filterlisten mit bracket-quotierten Objektnamen.', 10, 1) WITH NOWAIT;
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[schemas] AS [s] WITH (NOLOCK) WHERE [s].[name] = N'monitor')
BEGIN
    EXEC [sys].[sp_executesql] N'CREATE SCHEMA [monitor] AUTHORIZATION [dbo];';
END;
GO
-- END SOURCE: Code/00_Setup/000_Preflight_und_Schema.sql

-- BEGIN SOURCE: Code/01_Common/020_VW_AnalyseClassCatalog.sql
/*
===============================================================================
Objekt       : monitor.VW_AnalyseClassCatalog
Version      : 1.9.0
Stand        : 2026-07-22
Typ          : View
Zweck        : Definiert Analyseklassen, Kostenniveau und Pflicht zur
               AD-Gruppenprüfung für ressourcenintensive Module.
Parameter    : Keine.
Resultset    : AnalysisClass, AnalysisLevel, RequiresGroupGate,
               DefaultMaxRows, DefaultTimeoutSeconds, Description.
Berechtigung : SELECT auf der View; keine Rechtevergabe durch das Framework.
Policy       : Keine aktive Gruppendefinition = alle Klassen erlaubt; sobald
               Definitionen vorhanden sind, gelten die Regeln aus
               monitor.VW_AnalyseAccessPolicy. sysadmin besitzt Bypass.
Eigenlast    : Konstant.
Locking      : Keine fachlichen Tabellenzugriffe.
Aufruf       : SELECT * FROM monitor.VW_AnalyseClassCatalog;
Änderungen   : 1.9.0 - EXTERNAL_RUNTIME_CURRENT und CLR_CURRENT ergänzt.
               1.8.0 - SERVER_HEALTH_CURRENT, SERVER_CONFIGURATION_CURRENT und SECURITY_CONFIGURATION_CURRENT ergänzt.
               1.7.0 - SQL_AGENT_CURRENT, RESOURCE_GOVERNOR_CURRENT, HA_DR_CURRENT und ENTERPRISE_TOPOLOGY_DEEP ergänzt.
               1.6.0 - EXTENDED_EVENTS_CURRENT für leichte reine Sessioninventarisierung ergänzt.
               1.5.0 - QUERY_STORE_CURRENT für gezielte lesende Query-Store-Analysen ergänzt.
               1.4.0 - PLAN_CACHE_CURRENT und SHOWPLAN_TARGETED ergänzt.
               1.3.0 - INDEX_OPERATIONAL_DEEP ergänzt.
               1.2.0 - Zielgerichtete Phase-2-Analyseklassen ergänzt.
               1.1.0 - LOCKS_DEEP und LOG_VLF_DEEP ergänzt.
               1.0.0 - Erstfassung Phase 1A.
===============================================================================
*/
CREATE OR ALTER VIEW [monitor].[VW_AnalyseClassCatalog]
AS
    SELECT
        [v].[AnalysisClass],
        [v].[AnalysisLevel],
        [v].[RequiresGroupGate],
        [v].[DefaultMaxRows],
        [v].[DefaultTimeoutSeconds],
        [v].[Description]
    FROM
    (
        VALUES
          (CAST('STANDARD_CURRENT'                 AS varchar(64)), CAST('STANDARD' AS varchar(16)), CAST(0 AS bit), CAST(1000 AS int), CAST(10 AS int), CAST(N'Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O.' AS nvarchar(1000))),
          (CAST('EXTENDED_CURRENT'                 AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(2000 AS int), CAST(20 AS int), CAST(N'Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung.' AS nvarchar(1000))),
          (CAST('PLAN_CACHE_CURRENT'                AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(1000 AS int), CAST(30 AS int), CAST(N'Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding.' AS nvarchar(1000))),
          (CAST('SHOWPLAN_TARGETED'                 AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(100 AS int), CAST(30 AS int), CAST(N'Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes.' AS nvarchar(1000))),
          (CAST('OBJECT_ANALYSIS_CURRENT'           AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank.' AS nvarchar(1000))),
          (CAST('EXTERNAL_RUNTIME_CURRENT'          AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(2000 AS int), CAST(60 AS int), CAST(N'Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung.' AS nvarchar(1000))),
          (CAST('CLR_CURRENT'                       AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(2000 AS int), CAST(60 AS int), CAST(N'Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung.' AS nvarchar(1000))),
          (CAST('MISSING_INDEX_CURRENT'            AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung.' AS nvarchar(1000))),
          (CAST('STATISTICS_TARGETED'              AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte.' AS nvarchar(1000))),
          (CAST('COLUMNSTORE_CURRENT'              AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan.' AS nvarchar(1000))),
          (CAST('LOCKS_DEEP'                       AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(5000 AS int), CAST(60 AS int), CAST(N'Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge.' AS nvarchar(1000))),
          (CAST('LOG_VLF_DEEP'                     AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(20000 AS int), CAST(90 AS int), CAST(N'Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info.' AS nvarchar(1000))),
          (CAST('PLAN_CACHE_DEEP'                  AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(5000 AS int), CAST(60 AS int), CAST(N'Breite oder vollständige Analyse von Query Stats und Plan Cache.' AS nvarchar(1000))),
          (CAST('SHOWPLAN_XML_DEEP'                AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(1000 AS int), CAST(90 AS int), CAST(N'XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken.' AS nvarchar(1000))),
          (CAST('CATALOG_DEEP'                     AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(10000 AS int), CAST(90 AS int), CAST(N'Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse.' AS nvarchar(1000))),
          (CAST('PHYSICAL_STATS_DEEP'              AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(10000 AS int), CAST(180 AS int), CAST(N'Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus.' AS nvarchar(1000))),
          (CAST('INDEX_OPERATIONAL_DEEP'           AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(10000 AS int), CAST(120 AS int), CAST(N'Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern.' AS nvarchar(1000))),
          (CAST('QUERY_STORE_CURRENT'              AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(1000 AS int), CAST(30 AS int), CAST(N'Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit.' AS nvarchar(1000))),
          (CAST('EXTENDED_EVENTS_CURRENT'           AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie.' AS nvarchar(1000))),
          (CAST('QUERY_STORE_DEEP'                 AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(10000 AS int), CAST(120 AS int), CAST(N'Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen.' AS nvarchar(1000))),
          (CAST('CROSS_DATABASE_DEEP'              AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(20000 AS int), CAST(180 AS int), CAST(N'Datenbankübergreifende Inventarisierung und Diagnose.' AS nvarchar(1000))),
          (CAST('COLUMNSTORE_DEEP'                 AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(10000 AS int), CAST(120 AS int), CAST(N'Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten.' AS nvarchar(1000))),
          (CAST('EXTENDED_EVENTS_FORENSICS_DEEP'   AS varchar(64)), CAST('FORENSIK' AS varchar(16)), CAST(1 AS bit), CAST(5000 AS int), CAST(120 AS int), CAST(N'Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs.' AS nvarchar(1000))),
          (CAST('SERVER_HEALTH_CURRENT'             AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(2000 AS int), CAST(30 AS int), CAST(N'CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz.' AS nvarchar(1000))),
          (CAST('SERVER_CONFIGURATION_CURRENT'      AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(2000 AS int), CAST(30 AS int), CAST(N'Lesende Serverkonfiguration, Trace Flags und Startup-Parameter.' AS nvarchar(1000))),
          (CAST('SECURITY_CONFIGURATION_CURRENT'    AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(2000 AS int), CAST(30 AS int), CAST(N'Lesende sicherheits- und dienstbezogene Betriebsparameter.' AS nvarchar(1000))),
          (CAST('SQL_AGENT_CURRENT'                 AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb.' AS nvarchar(1000))),
          (CAST('RESOURCE_GOVERNOR_CURRENT'           AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(30 AS int), CAST(N'Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse.' AS nvarchar(1000))),
          (CAST('HA_DR_CURRENT'                       AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(5000 AS int), CAST(60 AS int), CAST(N'Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking.' AS nvarchar(1000))),
          (CAST('ENTERPRISE_TOPOLOGY_DEEP'            AS varchar(64)), CAST('DEEP' AS varchar(16)), CAST(1 AS bit), CAST(10000 AS int), CAST(120 AS int), CAST(N'Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication.' AS nvarchar(1000))),
          (CAST('DATA_PLATFORM_ADAPTER_CURRENT'          AS varchar(64)), CAST('ERWEITERT' AS varchar(16)), CAST(0 AS bit), CAST(1000 AS int), CAST(15 AS int), CAST(N'Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung.' AS nvarchar(1000)))
    ) AS [v]
    (
        [AnalysisClass],
        [AnalysisLevel],
        [RequiresGroupGate],
        [DefaultMaxRows],
        [DefaultTimeoutSeconds],
        [Description]
    );
GO
-- END SOURCE: Code/01_Common/020_VW_AnalyseClassCatalog.sql

-- BEGIN SOURCE: Code/01_Common/030_VW_AnalyseAccessPolicy.sql
/*
===============================================================================
Objekt       : monitor.VW_AnalyseAccessPolicy
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Stellt die rein lesende Policyquelle für eine oder mehrere
               AD-Gruppen je ressourcenintensiver Analyseklasse bereit.
Standard     : Die ausgelieferte View enthält keine Zeilen. Solange keine aktive
               Gruppendefinition vorhanden ist, sind alle Analyseklassen erlaubt.
Policy       : Sobald mindestens eine aktive Definition vorhanden ist, sind
               gruppengeschützte Analyseklassen nur für passende Gruppen erlaubt.
               Ein Eintrag mit AnalysisClass='*' gilt für alle geschützten Klassen.
Sysadmin     : sysadmin wird unabhängig von Gruppenregeln immer zugelassen.
Fallback     : Die effektive Prüfung verwendet zuerst sys.login_token und danach
               IS_MEMBER als Fallback.
Parameter    : Keine.
Resultset    : AnalysisClass, ADGroupName, IsEnabled, ValidFromUtc, ValidToUtc,
               Priority, Comment.
Berechtigung : SELECT auf der View; keinerlei GRANT/DENY/REVOKE im Framework.
Änderung     : Gruppen werden später durch CREATE OR ALTER VIEW gepflegt.
Beispiel     : Siehe kommentierte VALUES-Vorlage am Dateiende.
Änderungen   : 1.0.0 - Erstfassung Phase 1A.
===============================================================================
*/
CREATE OR ALTER VIEW [monitor].[VW_AnalyseAccessPolicy]
AS
    SELECT
        [p].[AnalysisClass],
        [p].[ADGroupName],
        [p].[IsEnabled],
        [p].[ValidFromUtc],
        [p].[ValidToUtc],
        [p].[Priority],
        [p].[Comment]
    FROM
    (
        VALUES
        (
            CAST(NULL AS varchar(64)),
            CAST(NULL AS nvarchar(256)),
            CAST(NULL AS bit),
            CAST(NULL AS datetime2(0)),
            CAST(NULL AS datetime2(0)),
            CAST(NULL AS smallint),
            CAST(NULL AS nvarchar(1000))
        )
    ) AS [p]
    (
        [AnalysisClass],
        [ADGroupName],
        [IsEnabled],
        [ValidFromUtc],
        [ValidToUtc],
        [Priority],
        [Comment]
    )
    WHERE 1 = 0;
GO

/*
Beispiel für eine spätere, bewusst manuell gepflegte Policy-View:

CREATE OR ALTER VIEW monitor.VW_AnalyseAccessPolicy
AS
    SELECT
        p.AnalysisClass,
        p.ADGroupName,
        p.IsEnabled,
        p.ValidFromUtc,
        p.ValidToUtc,
        p.Priority,
        p.Comment
    FROM
    (
        VALUES
          (CAST('PLAN_CACHE_DEEP' AS varchar(64)), CAST(N'CONTOSO\\SQL_Monitor_Deep' AS nvarchar(256)), CAST(1 AS bit), CAST(NULL AS datetime2(0)), CAST(NULL AS datetime2(0)), CAST(100 AS smallint), CAST(N'Plan-Cache Deep Analysis' AS nvarchar(1000))),
          (CAST('SHOWPLAN_XML_DEEP' AS varchar(64)), CAST(N'CONTOSO\\SQL_Monitor_Deep' AS nvarchar(256)), CAST(1 AS bit), CAST(NULL AS datetime2(0)), CAST(NULL AS datetime2(0)), CAST(100 AS smallint), CAST(N'Showplan XML Deep Analysis' AS nvarchar(1000))),
          (CAST('*' AS varchar(64)), CAST(N'CONTOSO\\SQL_Server_Admins' AS nvarchar(256)), CAST(1 AS bit), CAST(NULL AS datetime2(0)), CAST(NULL AS datetime2(0)), CAST(10 AS smallint), CAST(N'Alle geschützten Analyseklassen' AS nvarchar(1000)))
    ) AS [p]
    (
        [AnalysisClass],
        [ADGroupName],
        [IsEnabled],
        [ValidFromUtc],
        [ValidToUtc],
        [Priority],
        [Comment]
    );
GO
*/
-- END SOURCE: Code/01_Common/030_VW_AnalyseAccessPolicy.sql

-- BEGIN SOURCE: Code/01_Common/040_VW_AnalyseAccessCurrent.sql
/*
===============================================================================
Objekt       : monitor.VW_AnalyseAccessCurrent
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Ermittelt den effektiven Zugriff des aktuellen Logins auf jede
               Analyseklasse.
Priorität    : 1. ungeschützte Klasse, 2. sysadmin-Bypass, 3. offene Policy bei
               null aktiven Regeln, 4. Match über sys.login_token, 5. IS_MEMBER.
Parameter    : Keine.
Resultset    : Login-/Policy-/Matchinformationen und IsAllowed je Analyseklasse.
Berechtigung : Benötigt Lesbarkeit der Framework-Views und der für den aktuellen
               Login verfügbaren Tokeninformationen. Keine Rechtevergabe.
Eigenlast    : Sehr gering; liest nur kleine konstante Views, sys.login_token
               und führt IS_MEMBER ausschließlich für aktive Policyzeilen aus.
Locking      : Keine Benutzerobjekte; keine persistierenden Schreibzugriffe.
Hinweis      : AD-Tokenänderungen werden erst bei einer neuen Anmeldung sicher
               sichtbar. IS_MEMBER liefert bei SQL Logins typischerweise NULL.
Aufruf       : SELECT * FROM monitor.VW_AnalyseAccessCurrent;
Änderungen   : 1.0.0 - Erstfassung Phase 1A.
===============================================================================
*/
CREATE OR ALTER VIEW [monitor].[VW_AnalyseAccessCurrent]
AS
    WITH ActivePolicy AS
    (
        SELECT
            [p].[AnalysisClass],
            [p].[ADGroupName],
            [p].[Priority]
        FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
        WHERE [p].[IsEnabled] = 1
          AND ([p].[ValidFromUtc] IS NULL OR [p].[ValidFromUtc] <= SYSUTCDATETIME())
          AND ([p].[ValidToUtc]   IS NULL OR [p].[ValidToUtc]   >  SYSUTCDATETIME())
          AND NULLIF(LTRIM(RTRIM([p].[AnalysisClass])), '') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM([p].[ADGroupName])), '') IS NOT NULL
    ),
    PolicyState AS
    (
        SELECT COUNT_BIG(*) AS [ActivePolicyCount]
        FROM [ActivePolicy]
    ),
    LoginTokenMatches AS
    (
        SELECT DISTINCT
            [p].[AnalysisClass],
            [p].[ADGroupName]
        FROM [ActivePolicy] AS [p]
        INNER JOIN [sys].[login_token] AS [lt] WITH (NOLOCK)
            ON UPPER(CONVERT(nvarchar(256), [lt].[name])) COLLATE Latin1_General_100_CI_AS
             = UPPER([p].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
        WHERE [lt].[type] = N'WINDOWS GROUP'
    ),
    IsMemberMatches AS
    (
        SELECT DISTINCT
            [p].[AnalysisClass],
            [p].[ADGroupName]
        FROM [ActivePolicy] AS [p]
        WHERE IS_MEMBER([p].[ADGroupName]) = 1
    ),
    MatchRollup AS
    (
        SELECT
            [m].[AnalysisClass],
            COUNT_BIG(*) AS [MatchCount],
            MAX(CASE WHEN [m].[MatchSource] = 'LOGIN_TOKEN' THEN 1 ELSE 0 END) AS [HasLoginTokenMatch],
            MAX(CASE WHEN [m].[MatchSource] = 'IS_MEMBER'   THEN 1 ELSE 0 END) AS [HasIsMemberMatch]
        FROM
        (
            SELECT [ltm].[AnalysisClass], [ltm].[ADGroupName], CAST('LOGIN_TOKEN' AS varchar(20)) AS [MatchSource]
            FROM [LoginTokenMatches] AS [ltm]
            UNION ALL
            SELECT [imm].[AnalysisClass], [imm].[ADGroupName], CAST('IS_MEMBER' AS varchar(20)) AS [MatchSource]
            FROM [IsMemberMatches] AS [imm]
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [LoginTokenMatches] AS [ltm]
                WHERE [ltm].[AnalysisClass] = [imm].[AnalysisClass]
                  AND UPPER([ltm].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
                    = UPPER([imm].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
            )
        ) AS [m]
        GROUP BY [m].[AnalysisClass]
    )
    SELECT
        [c].[AnalysisClass],
        [c].[AnalysisLevel],
        [c].[RequiresGroupGate],
        ORIGINAL_LOGIN() AS [OriginalLoginName],
        SUSER_SNAME() AS [EffectiveLoginName],
        CAST(CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1 ELSE 0 END AS bit) AS [IsSysadmin],
        [ps].[ActivePolicyCount],
        CAST
        (
            (
                SELECT COUNT_BIG(*)
                FROM [ActivePolicy] AS [p]
                WHERE [p].[AnalysisClass] IN ([c].[AnalysisClass], '*')
            ) AS bigint
        ) AS [RelevantPolicyCount],
        CAST
        (
            CASE
                WHEN [c].[RequiresGroupGate] = 0 THEN 1
                WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1
                WHEN [ps].[ActivePolicyCount] = 0 THEN 1
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                      AND [mr].[MatchCount] > 0
                ) THEN 1
                ELSE 0
            END
            AS bit
        ) AS [IsAllowed],
        CAST
        (
            CASE
                WHEN [c].[RequiresGroupGate] = 0 THEN 'NOT_REQUIRED'
                WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 'SYSADMIN'
                WHEN [ps].[ActivePolicyCount] = 0 THEN 'OPEN_POLICY'
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                      AND [mr].[HasLoginTokenMatch] = 1
                ) THEN 'LOGIN_TOKEN'
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                      AND [mr].[HasIsMemberMatch] = 1
                ) THEN 'IS_MEMBER'
                ELSE 'NO_MATCH'
            END
            AS varchar(20)
        ) AS [AccessReason],
        CAST
        (
            COALESCE
            (
                (
                    SELECT SUM([mr].[MatchCount])
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                ),
                0
            ) AS bigint
        ) AS [MatchedGroupCount]
    FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
    CROSS JOIN [PolicyState] AS [ps];
GO
-- END SOURCE: Code/01_Common/040_VW_AnalyseAccessCurrent.sql

-- BEGIN SOURCE: Code/01_Common/078_TVF_ParsePipeList.sql
/*
===============================================================================
Objekt       : monitor.TVF_ParsePipeList
Version      : 1.1.0
Stand        : 2026-07-15
Typ          : Multi-statement Table-valued Function
Zweck        : Zerlegt eine Pipe-Liste. Das Zeichen | trennt ausschließlich
               außerhalb bracket-quotierter Bereiche. Innerhalb von [...] ist
               | Bestandteil des Werts; ]] maskiert eine schließende Klammer.
SQL-Version  : SQL Server 2019 oder neuer.
Parameter    : @List nvarchar(max).
Resultset    : ItemOrdinal, ItemText, IsBracketQuoted, IsValid, ErrorCode,
               ErrorMessage.
Collation    : Werte werden unter SQL_Latin1_General_CP1_CS_AS zurückgegeben.
Hinweis      : Die Funktion validiert die Listenstruktur. Die fachliche Prüfung
               als sysname, Zahl, Hash oder Multipart-Identifier erfolgt beim
               jeweiligen Verbraucher.
Beispiele    : SELECT * FROM monitor.TVF_ParsePipeList(N'dbo|monitor');
               SELECT * FROM monitor.TVF_ParsePipeList(
                   N'[Das ist | ein komischer Objektname]|[der auch]|der_auch');
Änderungen   : 1.1.0 - Nicht maskierte schließende Klammern, leere Elemente und
                         überlange Listenelemente werden zuverlässig erkannt.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParsePipeList]
(
    @List nvarchar(max)
)
RETURNS @Items TABLE
(
      [ItemOrdinal]      int             NOT NULL
    , [ItemText]         nvarchar(4000)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsBracketQuoted]  bit             NOT NULL
    , [IsValid]          bit             NOT NULL
    , [ErrorCode]        varchar(40)     COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ErrorMessage]     nvarchar(4000)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
)
AS
BEGIN
    IF @List IS NULL
        RETURN;

    DECLARE @Length int = DATALENGTH(@List) / 2;
    DECLARE @Position int = 1;
    DECLARE @StartPosition int = 1;
    DECLARE @ItemOrdinal int = 0;
    DECLARE @InBracket bit = 0;
    DECLARE @ItemHasSyntaxError bit = 0;
    DECLARE @Character nchar(1);
    DECLARE @NextCharacter nchar(1);

    IF @Length = 0
    BEGIN
        INSERT @Items
        (
              [ItemOrdinal], [ItemText], [IsBracketQuoted], [IsValid]
            , [ErrorCode], [ErrorMessage]
        )
        VALUES
        (
              1, N'', 0, 0
            , 'EMPTY_LIST', N'Die Liste darf nicht leer sein.'
        );
        RETURN;
    END;

    WHILE @Position <= @Length + 1
    BEGIN
        SET @Character = CASE WHEN @Position <= @Length
                              THEN SUBSTRING(@List, @Position, 1)
                         END;
        SET @NextCharacter = CASE WHEN @Position < @Length
                                  THEN SUBSTRING(@List, @Position + 1, 1)
                             END;

        IF @Position <= @Length AND @InBracket = 1
        BEGIN
            IF @Character = N']'
            BEGIN
                IF @NextCharacter = N']'
                    SET @Position += 1;
                ELSE
                    SET @InBracket = 0;
            END;
        END
        ELSE IF @Position <= @Length AND @Character = N'['
        BEGIN
            SET @InBracket = 1;
        END
        ELSE IF @Position <= @Length AND @Character = N']'
        BEGIN
            SET @ItemHasSyntaxError = 1;
        END
        ELSE IF @Position = @Length + 1 OR @Character = N'|'
        BEGIN
            DECLARE @RawLength int = @Position - @StartPosition;
            DECLARE @RawItem nvarchar(4000) =
                CASE WHEN @RawLength <= 4000
                     THEN CONVERT(nvarchar(4000), SUBSTRING(@List, @StartPosition, @RawLength))
                END;
            DECLARE @ItemText nvarchar(4000) = LTRIM(RTRIM(@RawItem));
            DECLARE @IsBracketQuoted bit = CONVERT
            (
                bit,
                CASE WHEN @ItemText IS NOT NULL
                           AND LEFT(@ItemText, 1) = N'['
                           AND RIGHT(@ItemText, 1) = N']'
                     THEN 1 ELSE 0 END
            );
            DECLARE @ErrorCode varchar(40) =
                CASE WHEN @RawLength > 4000 THEN 'ITEM_TOO_LONG'
                     WHEN @ItemText = N'' THEN 'EMPTY_ITEM'
                     WHEN @ItemHasSyntaxError = 1 OR @InBracket = 1 THEN 'INVALID_BRACKET_SYNTAX'
                END;

            SET @ItemOrdinal += 1;

            INSERT @Items
            (
                  [ItemOrdinal], [ItemText], [IsBracketQuoted], [IsValid]
                , [ErrorCode], [ErrorMessage]
            )
            VALUES
            (
                  @ItemOrdinal
                , @ItemText
                , @IsBracketQuoted
                , CONVERT(bit, CASE WHEN @ErrorCode IS NULL THEN 1 ELSE 0 END)
                , @ErrorCode
                , CASE @ErrorCode
                      WHEN 'ITEM_TOO_LONG' THEN N'Ein Listenelement darf höchstens 4000 Zeichen enthalten.'
                      WHEN 'EMPTY_ITEM' THEN N'Ein Listenelement darf nicht leer sein.'
                      WHEN 'INVALID_BRACKET_SYNTAX' THEN N'Die bracket-quotierte Schreibweise ist syntaktisch ungültig oder nicht abgeschlossen.'
                  END
            );

            SET @StartPosition = @Position + 1;
            SET @ItemHasSyntaxError = 0;
        END;

        SET @Position += 1;
    END;

    RETURN;
END;
GO
-- END SOURCE: Code/01_Common/078_TVF_ParsePipeList.sql

-- BEGIN SOURCE: Code/01_Common/085_TVF_ParseBigintList.sql
/*
===============================================================================
Objekt       : monitor.TVF_ParseBigintList
Version      : 1.1.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Validiert eine mit Pipe, Beistrich oder Strichpunkt getrennte
               Liste ganzzahliger bigint-Werte. Die Trennzeichen dürfen gemischt
               verwendet werden. Diese Funktion ist für Session-, Query-,
               Index- und andere numerische ID-Listen vorgesehen und verwendet
               bewusst keinen Identifier-Parser.
SQL-Version  : SQL Server 2019 oder neuer.
Beispiele    : SELECT * FROM monitor.TVF_ParseBigintList(N'57|61');
               SELECT * FROM monitor.TVF_ParseBigintList(N'57, 61;72');
Aenderungen  : 1.1.0 - Beistrich und Strichpunkt als weitere Trennzeichen.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseBigintList]
(
    @List nvarchar(max)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
          [l].[ItemOrdinal]
        , [l].[ItemText]
        , [NumberValue] = TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText])))
        , [IsValid] = CONVERT(bit,
              CASE WHEN [l].[IsValid] = 1
                     AND TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NOT NULL
                   THEN 1 ELSE 0 END)
        , [ErrorCode] = CONVERT(varchar(40),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
                   WHEN TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NULL
                   THEN 'INVALID_BIGINT' END)
        , [ErrorMessage] = CONVERT(nvarchar(4000),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorMessage]
                   WHEN TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NULL
                   THEN N'Das Listenelement ist keine gültige bigint-Ganzzahl.' END)
    FROM [monitor].[TVF_ParsePipeList]
         (TRANSLATE(@List, N',;', N'||')) AS [l]
);
GO
-- END SOURCE: Code/01_Common/085_TVF_ParseBigintList.sql

-- BEGIN SOURCE: Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql
/*
===============================================================================
Objekt       : monitor.InternalCheckAnalysisPath
Version      : 1.1.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Prüft einen tatsächlich aktivierten Analysepfad auf bekannte
               Klasse, High-Impact-Bestätigung und aktuelle Freigabe, bevor
               fachliche DMV-, Cache-, Query-Store- oder Katalogzugriffe
               beginnen.
Fallback     : Kann der serverseitige Login-Token unter EXECUTE AS USER oder
               einem vergleichbaren datenbankgebundenen Kontext nicht gelesen
               werden, bleiben ungeschützte Klassen, sysadmin und offene Policy
               erlaubt. Eine aktive gruppengeschützte Policy wird konservativ
               als DENIED_GROUP behandelt; sie wird niemals still umgangen.
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
-- END SOURCE: Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql

-- BEGIN SOURCE: Code/01_Common/095_USP_InternalWriteResultTable.sql
/*
===============================================================================
Objekt       : monitor.InternalWriteResultTable
Version      : 1.1.0
Stand        : 2026-07-19
Typ          : Interne Stored Procedure
Zweck        : Kopiert genau ein bereits materialisiertes Analyseergebnis in
               eine lokale Temp-Tabelle des Aufrufers. Eine leere Tabelle mit
               genau einer beliebigen Dummy-Spalte wird sicher an die native
               Quellstruktur angepasst; eine bereits passende Struktur wird
               zum Anhängen verwendet.
Sicherheit   : Ausschließlich lokale #Temp-Tabellen. Globale ##Temp-Tabellen
               und permanente Tabellen sind bewusst nicht zugelassen.
Locking      : Katalogauflösung ausschließlich über tempdb.sys.* WITH (NOLOCK)
               und LOCK_TIMEOUT 0; keine blockierenden Metadatenfunktionen.
===============================================================================
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [monitor].[InternalWriteResultTable]
      @SourceTable  sysname
    , @TargetTable  sysname
    , @InsertedRows bigint         = NULL OUTPUT
    , @StatusCode   varchar(40)    = NULL OUTPUT
    , @ErrorNumber  int            = NULL OUTPUT
    , @ErrorMessage nvarchar(2048) = NULL OUTPUT
    , @ThrowOnError bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Diese lokalen Tabellen entstehen vor LOCK_TIMEOUT 0. Der No-Wait-
    -- Vertrag gilt für die fremden Quell-/Ziel-Temp-Tabellen, nicht für die
    -- eigene tempdb-Metadatenanlage des Writers.
    CREATE TABLE [#InternalWriteResultTable_SourceSchema]
    (
          [ColumnId] int NOT NULL
        , [ColumnName] sysname NOT NULL
        , [TypeName] sysname NOT NULL
        , [SystemTypeId] tinyint NOT NULL
        , [MaxLength] smallint NOT NULL
        , [Precision] tinyint NOT NULL
        , [Scale] tinyint NOT NULL
        , [CollationName] sysname NULL
        , [IsNullable] bit NOT NULL
        , [IsIdentity] bit NOT NULL
        , [IsComputed] bit NOT NULL
        , [IsUserDefined] bit NOT NULL
        , [IsAssemblyType] bit NOT NULL
        , [XmlCollectionId] int NOT NULL
    );

    CREATE TABLE [#InternalWriteResultTable_TargetSchema]
    (
          [ColumnId] int NOT NULL
        , [ColumnName] sysname NOT NULL
        , [TypeName] sysname NOT NULL
        , [SystemTypeId] tinyint NOT NULL
        , [MaxLength] smallint NOT NULL
        , [Precision] tinyint NOT NULL
        , [Scale] tinyint NOT NULL
        , [CollationName] sysname NULL
        , [IsNullable] bit NOT NULL
        , [IsIdentity] bit NOT NULL
        , [IsComputed] bit NOT NULL
        , [IsUserDefined] bit NOT NULL
        , [IsAssemblyType] bit NOT NULL
        , [XmlCollectionId] int NOT NULL
    );

    SET LOCK_TIMEOUT 0;

    DECLARE @TableThrowMessage nvarchar(2048);

    SELECT
          @InsertedRows = 0
        , @StatusCode = 'AVAILABLE'
        , @ErrorNumber = NULL
        , @ErrorMessage = NULL;

    IF @ThrowOnError IS NULL OR @ThrowOnError NOT IN (0,1)
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'@ThrowOnError muss 0 oder 1 enthalten.';
        GOTO TableWriteFailed;
    END;

    IF @SourceTable IS NULL
       OR LEFT(@SourceTable, 1) <> N'#'
       OR LEFT(@SourceTable, 2) = N'##'
       OR @TargetTable IS NULL
       OR LEFT(@TargetTable, 1) <> N'#'
       OR LEFT(@TargetTable, 2) = N'##'
       OR LEN(@SourceTable) > 116
       OR LEN(@TargetTable) > 116
       OR @TargetTable LIKE N'#Monitor%' COLLATE Latin1_General_100_CI_AS
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'@SourceTable und @TargetTable müssen lokale #Temp-Tabellen bezeichnen; ##Temp-, permanente Tabellen und das reservierte Präfix #Monitor sind nicht zulässig.';
        GOTO TableWriteFailed;
    END;

    IF @SourceTable = @TargetTable COLLATE Latin1_General_100_CI_AS
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'Quell- und Zieltabelle dürfen nicht identisch sein.';
        GOTO TableWriteFailed;
    END;

    DECLARE @SourceObjectId int = NULL;
    DECLARE @TargetObjectId int = NULL;
    DECLARE @SourceMarker sysname = N'__MonitorResolveSource_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
    DECLARE @TargetMarker sysname = N'__MonitorResolveTarget_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
    DECLARE @ResolveSql nvarchar(max);

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@SourceTable)
                        + N' ADD ' + QUOTENAME(@SourceMarker) + N' bit NULL;';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'SOURCE_NOT_FOUND' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'Die interne Quelltabelle des ausgewählten Resultsets konnte nicht aufgelöst werden: ' + ERROR_MESSAGE();
        GOTO TableWriteFailed;
    END CATCH;

    SELECT @SourceObjectId = [c].[object_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [c].[object_id]
    WHERE [c].[name] = @SourceMarker;

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@SourceTable)
                        + N' DROP COLUMN ' + QUOTENAME(@SourceMarker) + N';';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'Die temporäre Quellmarkierung konnte nicht entfernt werden: ' + ERROR_MESSAGE();
        GOTO TableWriteFailed;
    END CATCH;

    IF @SourceObjectId IS NULL
    BEGIN
        SELECT
              @StatusCode = 'METADATA_NOT_VISIBLE'
            , @ErrorMessage = N'Die interne Quelltabelle ist vorhanden, ihre Katalogzeile war jedoch ohne Warten nicht sichtbar.';
        GOTO TableWriteFailed;
    END;

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@TargetTable)
                        + N' ADD ' + QUOTENAME(@TargetMarker) + N' bit NULL;';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TARGET_NOT_FOUND' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'@TargetTable konnte nicht aufgelöst werden: ' + ERROR_MESSAGE();
        GOTO TableWriteFailed;
    END CATCH;

    SELECT @TargetObjectId = [c].[object_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [c].[object_id]
    WHERE [c].[name] = @TargetMarker;

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@TargetTable)
                        + N' DROP COLUMN ' + QUOTENAME(@TargetMarker) + N';';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'Die temporäre Zielmarkierung konnte nicht entfernt werden: ' + ERROR_MESSAGE();
        GOTO TableWriteFailed;
    END CATCH;

    IF @TargetObjectId IS NULL
    BEGIN
        SELECT
              @StatusCode = 'METADATA_NOT_VISIBLE'
            , @ErrorMessage = N'@TargetTable ist vorhanden, ihre Katalogzeile war jedoch ohne Warten nicht sichtbar.';
        GOTO TableWriteFailed;
    END;

    INSERT [#InternalWriteResultTable_SourceSchema]
    (
          [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
        , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
        , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
    )
    SELECT
          CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id]))
        , [c].[name]
        , [t].[name]
        , [c].[system_type_id]
        , [c].[max_length]
        , [c].[precision]
        , [c].[scale]
        , [c].[collation_name]
        , [c].[is_nullable]
        , [c].[is_identity]
        , [c].[is_computed]
        , [t].[is_user_defined]
        , [t].[is_assembly_type]
        , [c].[xml_collection_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[types] AS [t] WITH (NOLOCK)
      ON [t].[user_type_id] = [c].[user_type_id]
    WHERE [c].[object_id] = @SourceObjectId;

    IF NOT EXISTS (SELECT 1 FROM [#InternalWriteResultTable_SourceSchema])
    BEGIN
        SELECT
              @StatusCode = 'UNSUPPORTED_SOURCE_SCHEMA'
            , @ErrorMessage = N'Das ausgewählte Resultset besitzt keine exportierbaren Spalten.';
        GOTO TableWriteFailed;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM [#InternalWriteResultTable_SourceSchema]
        WHERE [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
           OR [TypeName] IN (N'timestamp', N'rowversion')
    )
    BEGIN
        SELECT
              @StatusCode = 'UNSUPPORTED_SOURCE_SCHEMA'
            , @ErrorMessage = N'Das ausgewählte Resultset enthält einen nicht sicher reproduzierbaren Datentyp oder eine berechnete Spalte.';
        GOTO TableWriteFailed;
    END;

    INSERT [#InternalWriteResultTable_TargetSchema]
    (
          [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
        , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
        , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
    )
    SELECT
          CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id]))
        , [c].[name]
        , [t].[name]
        , [c].[system_type_id]
        , [c].[max_length]
        , [c].[precision]
        , [c].[scale]
        , [c].[collation_name]
        , [c].[is_nullable]
        , [c].[is_identity]
        , [c].[is_computed]
        , [t].[is_user_defined]
        , [t].[is_assembly_type]
        , [c].[xml_collection_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[types] AS [t] WITH (NOLOCK)
      ON [t].[user_type_id] = [c].[user_type_id]
    WHERE [c].[object_id] = @TargetObjectId;

    DECLARE @TargetColumnCount int;
    DECLARE @TargetHasRows bit = 0;
    DECLARE @DummyColumnName sysname;
    DECLARE @TargetNeedsAdaptation bit = 0;

    SELECT
          @TargetColumnCount = COUNT(*)
        , @DummyColumnName = MAX([ColumnName])
    FROM [#InternalWriteResultTable_TargetSchema];

    IF EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
    )
    OR EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
    )
    OR EXISTS
    (
        SELECT 1
        FROM [#InternalWriteResultTable_TargetSchema]
        WHERE [IsIdentity] = 1
           OR [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
    )
        SET @TargetNeedsAdaptation = 1;

    IF @TargetNeedsAdaptation = 1
    BEGIN
        IF @TargetColumnCount <> 1
        BEGIN
            SELECT
                  @StatusCode = 'TARGET_SCHEMA_MISMATCH'
                , @ErrorMessage = N'Eine abweichende Zieltabelle wird nur dann automatisch angepasst, wenn sie leer ist und genau eine beliebige Dummy-Spalte besitzt.';
            GOTO TableWriteFailed;
        END;

        DECLARE @HasRowsSql nvarchar(max) =
            N'SELECT @HasRows = CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM '
            + QUOTENAME(@TargetTable)
            + N') THEN 1 ELSE 0 END);';

        BEGIN TRY
            EXEC [sys].[sp_executesql]
                  @HasRowsSql
                , N'@HasRows bit OUTPUT'
                , @HasRows = @TargetHasRows OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT
                  @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
                , @ErrorNumber = ERROR_NUMBER()
                , @ErrorMessage = ERROR_MESSAGE();
            GOTO TableWriteFailed;
        END CATCH;

        IF @TargetHasRows = 1
        BEGIN
            SELECT
                  @StatusCode = 'TARGET_SCHEMA_MISMATCH'
                , @ErrorMessage = N'Die Zieltabelle muss leer sein, bevor ihre einzelne Dummy-Spalte ersetzt werden kann.';
            GOTO TableWriteFailed;
        END;

        DECLARE @ColumnDefinitions nvarchar(max);

        SELECT @ColumnDefinitions = STUFF
        (
            (
                SELECT
                      N', '
                    + QUOTENAME([s].[ColumnName])
                    + N' '
                    + CASE
                          WHEN [s].[TypeName] IN (N'varchar', N'char', N'varbinary', N'binary')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CASE WHEN [s].[MaxLength] = -1 THEN N'MAX' ELSE CONVERT(nvarchar(10), [s].[MaxLength]) END + N')'
                          WHEN [s].[TypeName] IN (N'nvarchar', N'nchar')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CASE WHEN [s].[MaxLength] = -1 THEN N'MAX' ELSE CONVERT(nvarchar(10), [s].[MaxLength] / 2) END + N')'
                          WHEN [s].[TypeName] IN (N'decimal', N'numeric')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Precision]) + N',' + CONVERT(nvarchar(10), [s].[Scale]) + N')'
                          WHEN [s].[TypeName] IN (N'datetime2', N'datetimeoffset', N'time')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Scale]) + N')'
                          WHEN [s].[TypeName] = N'float'
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Precision]) + N')'
                          ELSE QUOTENAME([s].[TypeName])
                      END
                    + CASE WHEN [s].[CollationName] IS NULL THEN N'' ELSE N' COLLATE ' + [s].[CollationName] END
                    + CASE WHEN [s].[IsNullable] = 1 THEN N' NULL' ELSE N' NOT NULL' END
                FROM [#InternalWriteResultTable_SourceSchema] AS [s]
                ORDER BY [s].[ColumnId]
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'nvarchar(max)')
            , 1
            , 2
            , N''
        );

        DECLARE @BridgeColumnName sysname = N'__MonitorBridge_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
        WHILE EXISTS (SELECT 1 FROM [#InternalWriteResultTable_SourceSchema] WHERE [ColumnName] = @BridgeColumnName)
           OR EXISTS (SELECT 1 FROM [#InternalWriteResultTable_TargetSchema] WHERE [ColumnName] = @BridgeColumnName)
            SET @BridgeColumnName = N'__MonitorBridge_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');

        BEGIN TRY
            DECLARE @AlterSql nvarchar(max) =
                  N'ALTER TABLE ' + QUOTENAME(@TargetTable) + N' ADD ' + QUOTENAME(@BridgeColumnName) + N' bit NULL;'
                + N' ALTER TABLE ' + QUOTENAME(@TargetTable) + N' DROP COLUMN ' + QUOTENAME(@DummyColumnName) + N';'
                + N' ALTER TABLE ' + QUOTENAME(@TargetTable) + N' ADD ' + @ColumnDefinitions + N';'
                + N' ALTER TABLE ' + QUOTENAME(@TargetTable) + N' DROP COLUMN ' + QUOTENAME(@BridgeColumnName) + N';';

            EXEC [sys].[sp_executesql] @AlterSql;
        END TRY
        BEGIN CATCH
            SELECT
                  @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
                , @ErrorNumber = ERROR_NUMBER()
                , @ErrorMessage = ERROR_MESSAGE();
            GOTO TableWriteFailed;
        END CATCH;

        DELETE FROM [#InternalWriteResultTable_TargetSchema];

        INSERT [#InternalWriteResultTable_TargetSchema]
        (
              [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
            , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
            , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
        )
        SELECT
              CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id]))
            , [c].[name]
            , [t].[name]
            , [c].[system_type_id]
            , [c].[max_length]
            , [c].[precision]
            , [c].[scale]
            , [c].[collation_name]
            , [c].[is_nullable]
            , [c].[is_identity]
            , [c].[is_computed]
            , [t].[is_user_defined]
            , [t].[is_assembly_type]
            , [c].[xml_collection_id]
        FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
        JOIN [tempdb].[sys].[types] AS [t] WITH (NOLOCK)
          ON [t].[user_type_id] = [c].[user_type_id]
        WHERE [c].[object_id] = @TargetObjectId;
    END;

    IF EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
    )
    OR EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
    )
    OR EXISTS
    (
        SELECT 1
        FROM [#InternalWriteResultTable_TargetSchema]
        WHERE [IsIdentity] = 1
           OR [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
    )
    BEGIN
        SELECT
              @StatusCode = 'TARGET_SCHEMA_MISMATCH'
            , @ErrorMessage = N'Die vorhandene Struktur von @TargetTable stimmt nicht exakt mit dem ausgewählten Resultset überein.';
        GOTO TableWriteFailed;
    END;

    DECLARE @ColumnList nvarchar(max);

    SELECT @ColumnList = STUFF
    (
        (
            SELECT N', ' + QUOTENAME([s].[ColumnName])
            FROM [#InternalWriteResultTable_SourceSchema] AS [s]
            ORDER BY [s].[ColumnId]
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'nvarchar(max)')
        , 1
        , 2
        , N''
    );

    BEGIN TRY
        DECLARE @InsertSql nvarchar(max) =
              N'INSERT ' + QUOTENAME(@TargetTable) + N' (' + @ColumnList + N')'
            + N' SELECT ' + @ColumnList + N' FROM ' + QUOTENAME(@SourceTable) + N';'
            + N' SET @Rows = @@ROWCOUNT;';

        EXEC [sys].[sp_executesql]
              @InsertSql
            , N'@Rows bigint OUTPUT'
            , @Rows = @InsertedRows OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'TABLE_WRITE_ERROR'
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();
    END CATCH;

    IF @StatusCode <> 'AVAILABLE'
        GOTO TableWriteFailed;

    RETURN;

TableWriteFailed:
    IF @ThrowOnError = 1
    BEGIN
        SET @TableThrowMessage = CONCAT
        (
              N'TABLE-Ausgabe fehlgeschlagen ('
            , COALESCE(@StatusCode, N'UNKNOWN')
            , N'): '
            , COALESCE(@ErrorMessage, N'Unbekannter Fehler.')
        );
        THROW 51010, @TableThrowMessage, 1;
    END;
END;
GO
-- END SOURCE: Code/01_Common/095_USP_InternalWriteResultTable.sql

-- BEGIN SOURCE: Code/01_Common/096_USP_InternalPrepareResultTables.sql
/*
===============================================================================
Objekt       : monitor.InternalPrepareResultTables
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Validiert eine benannte TABLE-Mehrfachzuordnung vollständig vor
               dem ersten fachlichen Systemzugriff und befüllt eine lokale
               Mapping-Temp-Tabelle des Aufrufers.
Sicherheit   : Nur vorhandene, leere lokale #Temp-Tabellen mit genau einer
               Seed-Spalte. Doppelte Ziele und unbekannte Resultsetnamen werden
               atomar abgelehnt. Keine fachlichen Datenquellen werden gelesen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalPrepareResultTables]
      @ResultTablesJson    nvarchar(max)
    , @AllowedResultNames  nvarchar(max)
    , @MappingTable        sysname
    , @StatusCode          varchar(40)    = NULL OUTPUT
    , @ErrorMessage        nvarchar(2048) = NULL OUTPUT
    , @ThrowOnError        bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Lokale Metadatenobjekte werden vor dem bewussten No-Wait-Vertrag
    -- angelegt, damit eine kurzzeitige tempdb-DDL-Kollision nicht schon den
    -- rein internen Arbeitsbereich mit Fehler 1222 abbrechen lässt.
    CREATE TABLE [#InternalPrepareResultTables_Allowed]
    (
        [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
    );

    CREATE TABLE [#InternalPrepareResultTables_Parsed]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [JsonType] int NOT NULL
    );

    SET LOCK_TIMEOUT 0;

    SELECT
          @StatusCode = 'AVAILABLE'
        , @ErrorMessage = NULL;

    IF @ThrowOnError IS NULL OR @ThrowOnError NOT IN (0,1)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@ThrowOnError muss 0 oder 1 enthalten.';
        GOTO PreflightFailed;
    END;

    IF @MappingTable IS NULL
       OR LEFT(@MappingTable,1) <> N'#'
       OR LEFT(@MappingTable,2) = N'##'
       OR LEN(@MappingTable) > 116
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@MappingTable muss eine gültige lokale #Temp-Tabelle bezeichnen.';
        GOTO PreflightFailed;
    END;

    IF @ResultTablesJson IS NULL
       OR ISJSON(@ResultTablesJson) <> 1
       OR LEFT(LTRIM(@ResultTablesJson),1) <> N'{'
       OR RIGHT(RTRIM(@ResultTablesJson),1) <> N'}'
    BEGIN
        SET @StatusCode = 'INVALID_RESULT_TABLE_MAPPING';
        SET @ErrorMessage = N'@ResultTablesJson muss ein gültiges JSON-Objekt enthalten.';
        GOTO PreflightFailed;
    END;

    INSERT [#InternalPrepareResultTables_Allowed]([ResultName])
    SELECT CONVERT(sysname, LTRIM(RTRIM([value])))
    FROM STRING_SPLIT(COALESCE(@AllowedResultNames,N''),N'|')
    WHERE NULLIF(LTRIM(RTRIM([value])),N'') IS NOT NULL;

    BEGIN TRY
        INSERT [#InternalPrepareResultTables_Parsed]([ResultName],[TargetTable],[JsonType])
        SELECT
              CONVERT(sysname,[key])
            , CONVERT(sysname,[value])
            , [type]
        FROM OPENJSON(@ResultTablesJson);
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INVALID_RESULT_TABLE_MAPPING';
        SET @ErrorMessage = N'@ResultTablesJson enthält einen nicht unterstützten Namen oder Zielwert.';
        GOTO PreflightFailed;
    END CATCH;

    IF NOT EXISTS (SELECT 1 FROM [#InternalPrepareResultTables_Parsed])
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              WHERE [JsonType] <> 1
                 OR NULLIF(LTRIM(RTRIM([ResultName])),N'') IS NULL
                 OR NULLIF(LTRIM(RTRIM([TargetTable])),N'') IS NULL
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              GROUP BY [ResultName] COLLATE SQL_Latin1_General_CP1_CS_AS
              HAVING COUNT(*) > 1
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              GROUP BY [TargetTable] COLLATE Latin1_General_100_CI_AS
              HAVING COUNT(*) > 1
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed] AS [p]
              WHERE NOT EXISTS
                    (
                        SELECT 1
                        FROM [#InternalPrepareResultTables_Allowed] AS [a]
                        WHERE [a].[ResultName] = [p].[ResultName]
                              COLLATE SQL_Latin1_General_CP1_CS_AS
                    )
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              WHERE LEFT([TargetTable],1) <> N'#'
                 OR LEFT([TargetTable],2) = N'##'
                 OR LEN([TargetTable]) > 116
                 OR [TargetTable] LIKE N'#Monitor%' COLLATE Latin1_General_100_CI_AS
          )
    BEGIN
        SET @StatusCode = 'INVALID_RESULT_TABLE_MAPPING';
        SET @ErrorMessage = N'Die TABLE-Zuordnung enthält unbekannte oder doppelte Resultsetnamen, doppelte Ziele oder unzulässige Temp-Tabellennamen.';
        GOTO PreflightFailed;
    END;

    DECLARE @MappingTableQuoted nvarchar(258) = QUOTENAME(@MappingTable);
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        SET @Sql = N'DECLARE @ResultName sysname,@TargetTable sysname;
SELECT TOP (0) @ResultName=[ResultName],@TargetTable=[TargetTable]
FROM ' + @MappingTableQuoted + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die Mapping-Temp-Tabelle wurde nicht mit dem erwarteten Schema angelegt.';
        GOTO PreflightFailed;
    END CATCH;

    DECLARE @TargetTable sysname;
    DECLARE @TargetTableQuoted nvarchar(258);
    DECLARE @HasRows bit;
    DECLARE @Marker sysname;
    DECLARE @MarkerAdded bit;
    DECLARE @ColumnCount int;

    DECLARE [TargetCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [TargetTable]
        FROM [#InternalPrepareResultTables_Parsed]
        ORDER BY [ResultName];

    OPEN [TargetCursor];
    FETCH NEXT FROM [TargetCursor] INTO @TargetTable;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
              @TargetTableQuoted = QUOTENAME(@TargetTable)
            , @HasRows = NULL
            , @Marker = N'__MonitorPreflight_' + REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')
            , @MarkerAdded = 0
            , @ColumnCount = NULL;

        BEGIN TRY
            SET @Sql = N'SELECT @HasRows = CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM '
                     + @TargetTableQuoted + N') THEN 1 ELSE 0 END);';
            EXEC [sys].[sp_executesql] @Sql,N'@HasRows bit OUTPUT',@HasRows=@HasRows OUTPUT;

            IF @HasRows = 1
            BEGIN
                SET @StatusCode = 'INVALID_RESULT_TABLE_TARGET';
                SET @ErrorMessage = N'Alle TABLE-Ziele müssen vor dem Aufruf leer sein.';
                CLOSE [TargetCursor];
                DEALLOCATE [TargetCursor];
                GOTO PreflightFailed;
            END;

            SET @Sql = N'ALTER TABLE ' + @TargetTableQuoted
                     + N' ADD ' + QUOTENAME(@Marker) + N' bit NULL;';
            EXEC [sys].[sp_executesql] @Sql;
            SET @MarkerAdded = 1;

            SELECT @ColumnCount = COUNT(*)
            FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
            INNER JOIN [tempdb].[sys].[tables] AS [t] WITH (NOLOCK)
              ON [t].[object_id] = [c].[object_id]
            WHERE EXISTS
                  (
                      SELECT 1
                      FROM [tempdb].[sys].[columns] AS [m] WITH (NOLOCK)
                      WHERE [m].[object_id] = [t].[object_id]
                        AND [m].[name] = @Marker
                  );

            SET @Sql = N'ALTER TABLE ' + @TargetTableQuoted
                     + N' DROP COLUMN ' + QUOTENAME(@Marker) + N';';
            EXEC [sys].[sp_executesql] @Sql;
            SET @MarkerAdded = 0;

            IF @ColumnCount <> 2
            BEGIN
                SET @StatusCode = 'INVALID_RESULT_TABLE_TARGET';
                SET @ErrorMessage = N'Jedes neue TABLE-Ziel muss genau eine Seed-Spalte besitzen.';
                CLOSE [TargetCursor];
                DEALLOCATE [TargetCursor];
                GOTO PreflightFailed;
            END;
        END TRY
        BEGIN CATCH
            IF @MarkerAdded = 1
            BEGIN TRY
                SET @Sql = N'ALTER TABLE ' + @TargetTableQuoted
                         + N' DROP COLUMN ' + QUOTENAME(@Marker) + N';';
                EXEC [sys].[sp_executesql] @Sql;
            END TRY
            BEGIN CATCH
            END CATCH;

            SET @StatusCode = 'INVALID_RESULT_TABLE_TARGET';
            SET @ErrorMessage = N'Mindestens eine angeforderte lokale Ziel-Temp-Tabelle ist nicht vorhanden oder nicht sicher validierbar.';
            CLOSE [TargetCursor];
            DEALLOCATE [TargetCursor];
            GOTO PreflightFailed;
        END CATCH;

        FETCH NEXT FROM [TargetCursor] INTO @TargetTable;
    END;
    CLOSE [TargetCursor];
    DEALLOCATE [TargetCursor];

    SET @Sql = N'INSERT ' + @MappingTableQuoted + N'([ResultName],[TargetTable])
SELECT [ResultName],[TargetTable]
FROM [#InternalPrepareResultTables_Parsed];';
    EXEC [sys].[sp_executesql] @Sql;
    RETURN;

PreflightFailed:
    IF @ThrowOnError = 1
        THROW 51011, @ErrorMessage, 1;
END;
GO
-- END SOURCE: Code/01_Common/096_USP_InternalPrepareResultTables.sql

-- BEGIN SOURCE: Code/01_Common/098_USP_InternalEmitConsoleResult.sql
/*
===============================================================================
Objekt       : monitor.InternalEmitConsoleResult
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer
               bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern
               eine beschriftete Fachansicht. Leere Quellen liefern genau eine
               verständliche Console-Zeile; RAW und TABLE verwenden den Helper
               nicht und erhalten deshalb keine künstlichen Datenzeilen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalEmitConsoleResult]
      @SourceTable    sysname
    , @ResultLabel    nvarchar(200)
    , @EmptyMessage   nvarchar(200)
    , @StatusCode     varchar(40)    = NULL
    , @StatusMessage  nvarchar(2048) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    IF @SourceTable IS NULL
       OR LEFT(@SourceTable,1)<>N'#'
       OR LEFT(@SourceTable,2)=N'##'
       OR LEN(@SourceTable)>116
        THROW 51012,N'@SourceTable muss eine lokale #Temp-Tabelle des Aufrufers bezeichnen.',1;

    SET @ResultLabel=COALESCE(NULLIF(LTRIM(RTRIM(@ResultLabel)),N''),N'Ergebnis');
    SET @EmptyMessage=COALESCE(NULLIF(LTRIM(RTRIM(@EmptyMessage)),N''),N'Keine Ergebnisse');

    DECLARE @Sql nvarchar(max)=
          N'IF EXISTS (SELECT 1 FROM '+QUOTENAME(@SourceTable)+N')'
        + N' SELECT @Label AS [Ergebnis],[src].* FROM '+QUOTENAME(@SourceTable)+N' AS [src];'
        + N' ELSE SELECT @Empty AS [Ergebnis],@Status AS [Status],@Message AS [Hinweis];';

    EXEC [sys].[sp_executesql]
          @Sql
        , N'@Label nvarchar(200),@Empty nvarchar(200),@Status varchar(40),@Message nvarchar(2048)'
        , @Label=@ResultLabel
        , @Empty=@EmptyMessage
        , @Status=@StatusCode
        , @Message=@StatusMessage;
END;
GO
-- END SOURCE: Code/01_Common/098_USP_InternalEmitConsoleResult.sql

-- BEGIN SOURCE: Code/04_PlanCache/041_PlanAnalysisProfile.sql
/*
===============================================================================
Objekt       : monitor.PlanAnalysisProfile
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Steuertabelle
Zweck        : Definiert generische Workloadprofile für die eigenständige und
               frameworkintegrierte Execution-Plan-Analyse.
Datenschutz  : Enthält ausschließlich generische Frameworkwerte. Lokale reale
               Zuordnungen werden nicht als Repositoryseed ausgeliefert.
===============================================================================
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'PlanAnalysisProfile'
)
BEGIN
    CREATE TABLE [monitor].[PlanAnalysisProfile]
    (
          [ProfileCode]        varchar(32)    NOT NULL
        , [Description]        nvarchar(1000) NOT NULL
        , [Priority]           smallint       NOT NULL
        , [IsEnabled]          bit            NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_IsEnabled] DEFAULT (1)
        , [IsFrameworkDefault] bit            NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_IsFrameworkDefault] DEFAULT (0)
        , [SeedVersion]        int            NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_SeedVersion] DEFAULT (0)
        , [LastUpdatedUtc]     datetime2(0)   NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_PlanAnalysisProfile]
            PRIMARY KEY CLUSTERED ([ProfileCode])
        , CONSTRAINT [CK_PlanAnalysisProfile_Priority]
            CHECK ([Priority] BETWEEN 1 AND 32767)
    );
END;
GO

DECLARE @SeedVersion int=1;
DECLARE @Defaults TABLE
(
      [ProfileCode] varchar(32) NOT NULL PRIMARY KEY
    , [Description] nvarchar(1000) NOT NULL
    , [Priority] smallint NOT NULL
);

INSERT @Defaults([ProfileCode],[Description],[Priority])
VALUES
  ('LATENCY_SENSITIVE',N'Interaktive oder hochfrequente Zugriffe; je Ausführung und Wiederholungsrate werden stärker gewichtet.',100),
  ('BALANCED',N'Neutraler Frameworkstandard für gemischte Workloads ohne belastbare explizite Zuordnung.',200),
  ('THROUGHPUT',N'Mengen- und Durchsatzverarbeitung; absolute CPU-, I/O-, TempDB- und Datenmengen werden stärker gewichtet.',300),
  ('MAINTENANCE',N'Wartungs- und strukturverändernde Verarbeitung; große Scans und Sorts können fachlich erwartet sein.',400),
  ('UNKNOWN',N'Workloadprofil nicht belastbar bestimmbar; Findings bleiben konservativ und weisen die geringe Zuordnungssicherheit aus.',500);

UPDATE [p]
SET
      [p].[Description]=[d].[Description]
    , [p].[Priority]=[d].[Priority]
    , [p].[IsEnabled]=1
    , [p].[SeedVersion]=@SeedVersion
    , [p].[LastUpdatedUtc]=SYSUTCDATETIME()
FROM [monitor].[PlanAnalysisProfile] AS [p]
JOIN @Defaults AS [d]
  ON [d].[ProfileCode]=[p].[ProfileCode]
WHERE [p].[IsFrameworkDefault]=1
  AND [p].[SeedVersion]<@SeedVersion;

INSERT [monitor].[PlanAnalysisProfile]
(
      [ProfileCode],[Description],[Priority],[IsEnabled]
    , [IsFrameworkDefault],[SeedVersion]
)
SELECT [d].[ProfileCode],[d].[Description],[d].[Priority],1,1,@SeedVersion
FROM @Defaults AS [d]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisProfile] AS [p]
    WHERE [p].[ProfileCode]=[d].[ProfileCode]
);
GO
-- END SOURCE: Code/04_PlanCache/041_PlanAnalysisProfile.sql

-- BEGIN SOURCE: Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql
/*
===============================================================================
Objekt       : monitor.PlanAnalysisRuleThreshold
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Steuertabelle
Zweck        : Hält ausschließlich Datenwerte für plananalytische Schwellen.
               Die ausführbare Regellogik verbleibt in geprüftem T-SQL-Code.
Hinweis      : Alle ausgelieferten Werte sind Triageheuristiken und keine
               Microsoft-Grenzwerte oder automatische Tuninganweisung.
===============================================================================
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'PlanAnalysisRuleThreshold'
)
BEGIN
    CREATE TABLE [monitor].[PlanAnalysisRuleThreshold]
    (
          [RuleCode]                    varchar(100)  NOT NULL
        , [ProfileCode]                 varchar(32)   NOT NULL
        , [Severity]                    varchar(16)   NOT NULL
        , [IsEnabled]                   bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_IsEnabled] DEFAULT (1)
        , [MinRatio]                    decimal(19,6) NULL
        , [MaxRatio]                    decimal(19,6) NULL
        , [MinAbsoluteRows]             bigint        NULL
        , [MinRowsRead]                 bigint        NULL
        , [MinRowsNotReturned]          bigint        NULL
        , [MinRowsNotReturnedPercent]   decimal(9,4)  NULL
        , [MinExecutionCount]           bigint        NULL
        , [MinLogicalReadsPerExecution] bigint        NULL
        , [MinTotalLogicalReads]        bigint        NULL
        , [MinElapsedMs]                bigint        NULL
        , [MinCpuMs]                    bigint        NULL
        , [MinSpilledPages]             bigint        NULL
        , [MinMemoryKb]                 bigint        NULL
        , [MinServerMajorVersion]       tinyint       NULL
        , [MinCompatibilityLevel]       smallint      NULL
        , [RequiredEvidenceLevel]       varchar(32)   NULL
        , [AdditionalConfigurationJson] nvarchar(max) NULL
        , [IsFrameworkDefault]          bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_IsFrameworkDefault] DEFAULT (0)
        , [SeedVersion]                 int            NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_SeedVersion] DEFAULT (0)
        , [LastUpdatedUtc]              datetime2(0)   NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_PlanAnalysisRuleThreshold]
            PRIMARY KEY CLUSTERED ([RuleCode],[ProfileCode],[Severity])
        , CONSTRAINT [FK_PlanAnalysisRuleThreshold_Profile]
            FOREIGN KEY ([ProfileCode])
            REFERENCES [monitor].[PlanAnalysisProfile]([ProfileCode])
        , CONSTRAINT [CK_PlanAnalysisRuleThreshold_Severity]
            CHECK ([Severity] IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL'))
        , CONSTRAINT [CK_PlanAnalysisRuleThreshold_Json]
            CHECK ([AdditionalConfigurationJson] IS NULL OR ISJSON([AdditionalConfigurationJson])=1)
    );
END;
GO

DECLARE @SeedVersion int=1;
DECLARE @Defaults TABLE
(
      [RuleCode] varchar(100) NOT NULL
    , [ProfileCode] varchar(32) NOT NULL
    , [Severity] varchar(16) NOT NULL
    , [MinRatio] decimal(19,6) NULL
    , [MaxRatio] decimal(19,6) NULL
    , [MinAbsoluteRows] bigint NULL
    , [MinRowsRead] bigint NULL
    , [MinRowsNotReturned] bigint NULL
    , [MinRowsNotReturnedPercent] decimal(9,4) NULL
    , [MinExecutionCount] bigint NULL
    , [MinLogicalReadsPerExecution] bigint NULL
    , [MinTotalLogicalReads] bigint NULL
    , [MinElapsedMs] bigint NULL
    , [MinCpuMs] bigint NULL
    , [MinSpilledPages] bigint NULL
    , [MinMemoryKb] bigint NULL
    , [RequiredEvidenceLevel] varchar(32) NULL
    , [AdditionalConfigurationJson] nvarchar(max) NULL
    , PRIMARY KEY ([RuleCode],[ProfileCode],[Severity])
);

INSERT @Defaults
(
      [RuleCode],[ProfileCode],[Severity],[MinRatio],[MaxRatio]
    , [MinAbsoluteRows],[MinRowsRead],[MinRowsNotReturned]
    , [MinRowsNotReturnedPercent],[MinExecutionCount]
    , [MinLogicalReadsPerExecution],[MinTotalLogicalReads]
    , [MinElapsedMs],[MinCpuMs],[MinSpilledPages],[MinMemoryKb]
    , [RequiredEvidenceLevel],[AdditionalConfigurationJson]
)
VALUES
  ('CARDINALITY_UNDERESTIMATE','LATENCY_SENSITIVE','MEDIUM',3,NULL,100,NULL,NULL,NULL,100,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','LATENCY_SENSITIVE','HIGH',10,NULL,1000,NULL,NULL,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','BALANCED','MEDIUM',10,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','BALANCED','HIGH',100,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','THROUGHPUT','MEDIUM',5,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','THROUGHPUT','HIGH',20,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','MAINTENANCE','MEDIUM',20,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','MAINTENANCE','HIGH',100,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','UNKNOWN','MEDIUM',20,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','UNKNOWN','HIGH',200,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','LATENCY_SENSITIVE','MEDIUM',NULL,0.333333,100,NULL,NULL,NULL,100,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','LATENCY_SENSITIVE','HIGH',NULL,0.100000,1000,NULL,NULL,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','BALANCED','MEDIUM',NULL,0.100000,1000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','BALANCED','HIGH',NULL,0.010000,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','THROUGHPUT','MEDIUM',NULL,0.200000,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','THROUGHPUT','HIGH',NULL,0.050000,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','MAINTENANCE','MEDIUM',NULL,0.050000,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','MAINTENANCE','HIGH',NULL,0.010000,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','UNKNOWN','MEDIUM',NULL,0.050000,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','UNKNOWN','HIGH',NULL,0.005000,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','LATENCY_SENSITIVE','MEDIUM',NULL,NULL,NULL,10000,5000,50,100,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','LATENCY_SENSITIVE','HIGH',NULL,NULL,NULL,100000,50000,90,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','BALANCED','MEDIUM',NULL,NULL,NULL,100000,50000,50,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','BALANCED','HIGH',NULL,NULL,NULL,1000000,900000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','THROUGHPUT','MEDIUM',NULL,NULL,NULL,1000000,500000,50,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','THROUGHPUT','HIGH',NULL,NULL,NULL,10000000,9000000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','MAINTENANCE','MEDIUM',NULL,NULL,NULL,10000000,9000000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','MAINTENANCE','HIGH',NULL,NULL,NULL,100000000,95000000,95,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','UNKNOWN','MEDIUM',NULL,NULL,NULL,1000000,900000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','UNKNOWN','HIGH',NULL,NULL,NULL,10000000,9500000,95,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','LATENCY_SENSITIVE','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','LATENCY_SENSITIVE','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','BALANCED','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','BALANCED','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','THROUGHPUT','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','THROUGHPUT','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','MAINTENANCE','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','MAINTENANCE','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','UNKNOWN','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','UNKNOWN','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','LATENCY_SENSITIVE','MEDIUM',NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','LATENCY_SENSITIVE','HIGH',NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','BALANCED','MEDIUM',NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','BALANCED','HIGH',NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','THROUGHPUT','MEDIUM',NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','THROUGHPUT','HIGH',NULL,NULL,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','MAINTENANCE','MEDIUM',NULL,NULL,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','MAINTENANCE','HIGH',NULL,NULL,NULL,1000000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','UNKNOWN','MEDIUM',NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','UNKNOWN','HIGH',NULL,NULL,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','LATENCY_SENSITIVE','MEDIUM',4,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10240,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','BALANCED','MEDIUM',4,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10240,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','THROUGHPUT','MEDIUM',8,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,102400,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','MAINTENANCE','MEDIUM',16,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1048576,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','UNKNOWN','MEDIUM',8,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,102400,'RUNTIME_MEASURED',NULL),
  ('PARALLEL_THREAD_SKEW','LATENCY_SENSITIVE','MEDIUM',2,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','LATENCY_SENSITIVE','HIGH',4,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','BALANCED','MEDIUM',3,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','BALANCED','HIGH',8,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','THROUGHPUT','MEDIUM',4,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','THROUGHPUT','HIGH',10,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','MAINTENANCE','MEDIUM',8,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','MAINTENANCE','HIGH',20,NULL,1000000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','UNKNOWN','MEDIUM',5,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','UNKNOWN','HIGH',12,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}');

UPDATE [r]
SET
      [r].[IsEnabled]=1
    , [r].[MinRatio]=[d].[MinRatio]
    , [r].[MaxRatio]=[d].[MaxRatio]
    , [r].[MinAbsoluteRows]=[d].[MinAbsoluteRows]
    , [r].[MinRowsRead]=[d].[MinRowsRead]
    , [r].[MinRowsNotReturned]=[d].[MinRowsNotReturned]
    , [r].[MinRowsNotReturnedPercent]=[d].[MinRowsNotReturnedPercent]
    , [r].[MinExecutionCount]=[d].[MinExecutionCount]
    , [r].[MinLogicalReadsPerExecution]=[d].[MinLogicalReadsPerExecution]
    , [r].[MinTotalLogicalReads]=[d].[MinTotalLogicalReads]
    , [r].[MinElapsedMs]=[d].[MinElapsedMs]
    , [r].[MinCpuMs]=[d].[MinCpuMs]
    , [r].[MinSpilledPages]=[d].[MinSpilledPages]
    , [r].[MinMemoryKb]=[d].[MinMemoryKb]
    , [r].[RequiredEvidenceLevel]=[d].[RequiredEvidenceLevel]
    , [r].[AdditionalConfigurationJson]=[d].[AdditionalConfigurationJson]
    , [r].[SeedVersion]=@SeedVersion
    , [r].[LastUpdatedUtc]=SYSUTCDATETIME()
FROM [monitor].[PlanAnalysisRuleThreshold] AS [r]
JOIN @Defaults AS [d]
  ON [d].[RuleCode]=[r].[RuleCode]
 AND [d].[ProfileCode]=[r].[ProfileCode]
 AND [d].[Severity]=[r].[Severity]
WHERE [r].[IsFrameworkDefault]=1
  AND [r].[SeedVersion]<@SeedVersion;

INSERT [monitor].[PlanAnalysisRuleThreshold]
(
      [RuleCode],[ProfileCode],[Severity],[IsEnabled]
    , [MinRatio],[MaxRatio],[MinAbsoluteRows],[MinRowsRead]
    , [MinRowsNotReturned],[MinRowsNotReturnedPercent],[MinExecutionCount]
    , [MinLogicalReadsPerExecution],[MinTotalLogicalReads]
    , [MinElapsedMs],[MinCpuMs],[MinSpilledPages],[MinMemoryKb]
    , [RequiredEvidenceLevel],[AdditionalConfigurationJson]
    , [IsFrameworkDefault],[SeedVersion]
)
SELECT
      [d].[RuleCode],[d].[ProfileCode],[d].[Severity],1
    , [d].[MinRatio],[d].[MaxRatio],[d].[MinAbsoluteRows],[d].[MinRowsRead]
    , [d].[MinRowsNotReturned],[d].[MinRowsNotReturnedPercent],[d].[MinExecutionCount]
    , [d].[MinLogicalReadsPerExecution],[d].[MinTotalLogicalReads]
    , [d].[MinElapsedMs],[d].[MinCpuMs],[d].[MinSpilledPages],[d].[MinMemoryKb]
    , [d].[RequiredEvidenceLevel],[d].[AdditionalConfigurationJson]
    , 1,@SeedVersion
FROM @Defaults AS [d]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisRuleThreshold] AS [r]
    WHERE [r].[RuleCode]=[d].[RuleCode]
      AND [r].[ProfileCode]=[d].[ProfileCode]
      AND [r].[Severity]=[d].[Severity]
);
GO
-- END SOURCE: Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql

-- BEGIN SOURCE: Code/04_PlanCache/043_PlanAnalysisProfileAssignment.sql
/*
===============================================================================
Objekt       : monitor.PlanAnalysisProfileAssignment
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Steuertabelle
Zweck        : Ordnet Plan- und Workloadkontext optional einem generischen
               lokalen Analyseprofil zu. Die Auslieferung enthält keine realen
               Zuordnungen und überschreibt keine lokalen Zeilen.
===============================================================================
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'PlanAnalysisProfileAssignment'
)
BEGIN
    CREATE TABLE [monitor].[PlanAnalysisProfileAssignment]
    (
          [AssignmentId]          bigint        IDENTITY(1,1) NOT NULL
        , [Priority]              smallint      NOT NULL
        , [IsEnabled]             bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfileAssignment_IsEnabled] DEFAULT (1)
        , [ProfileCode]           varchar(32)   NOT NULL
        , [DatabaseNamePattern]   nvarchar(256) NULL
        , [SchemaNamePattern]     nvarchar(256) NULL
        , [ObjectNamePattern]     nvarchar(256) NULL
        , [QueryHash]             binary(8)     NULL
        , [QueryStoreQueryId]     bigint        NULL
        , [StatementId]           int           NULL
        , [ProgramNameLikePattern] nvarchar(256) NULL
        , [ResourcePoolId]        int           NULL
        , [WorkloadGroupId]       int           NULL
        , [IsFrameworkDefault]    bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfileAssignment_IsFrameworkDefault] DEFAULT (0)
        , [Comment]               nvarchar(1000) NULL
        , [LastUpdatedUtc]        datetime2(0)   NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfileAssignment_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_PlanAnalysisProfileAssignment]
            PRIMARY KEY CLUSTERED ([AssignmentId])
        , CONSTRAINT [FK_PlanAnalysisProfileAssignment_Profile]
            FOREIGN KEY ([ProfileCode])
            REFERENCES [monitor].[PlanAnalysisProfile]([ProfileCode])
        , CONSTRAINT [CK_PlanAnalysisProfileAssignment_Priority]
            CHECK ([Priority] BETWEEN 1 AND 32767)
        , CONSTRAINT [CK_PlanAnalysisProfileAssignment_Scope]
            CHECK
            (
                   [DatabaseNamePattern] IS NOT NULL
                OR [SchemaNamePattern] IS NOT NULL
                OR [ObjectNamePattern] IS NOT NULL
                OR [QueryHash] IS NOT NULL
                OR [QueryStoreQueryId] IS NOT NULL
                OR [StatementId] IS NOT NULL
                OR [ProgramNameLikePattern] IS NOT NULL
                OR [ResourcePoolId] IS NOT NULL
                OR [WorkloadGroupId] IS NOT NULL
            )
    );

    CREATE INDEX [IX_PlanAnalysisProfileAssignment_Resolution]
        ON [monitor].[PlanAnalysisProfileAssignment]
        ([IsEnabled],[Priority],[ProfileCode])
        INCLUDE
        (
              [DatabaseNamePattern],[SchemaNamePattern],[ObjectNamePattern]
            , [QueryHash],[QueryStoreQueryId],[StatementId]
            , [ProgramNameLikePattern],[ResourcePoolId],[WorkloadGroupId]
        );
END;
GO
-- END SOURCE: Code/04_PlanCache/043_PlanAnalysisProfileAssignment.sql

-- BEGIN SOURCE: Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql
/*
===============================================================================
Objekt       : monitor.TVF_ParseStatisticsIoText
Version      : 1.0.1
Stand        : 2026-07-21
Typ          : Multi-statement Table-valued Function
Zweck        : Parst bereits vorliegenden SET STATISTICS IO-Meldungstext ohne
               eine Query auszuführen. Die Ausgabe bleibt statement-/zeilenbezogen
               und kennzeichnet unvollständig erkannte Formate.
SQL-Version  : SQL Server 2019 oder neuer.
Grenzen      : SQL Server liefert menschenorientierten Meldungstext. Der Parser
               unterstützt das dokumentierte englische Format und gebräuchliche
               deutsche Bezeichner; unbekannte Formate werden nicht erfunden.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseStatisticsIoText]
(
      @StatisticsIoText   nvarchar(max)
    , @StatisticsLanguage varchar(16) = 'AUTO'
)
RETURNS @Result TABLE
(
      [StatementOrdinal]             int            NULL
    , [MessageOrdinal]               int            NOT NULL
    , [ObjectOrdinal]                int            NOT NULL
    , [ObjectDisplayName]            nvarchar(512)  NULL
    , [ScanCount]                    bigint         NULL
    , [LogicalReads]                 bigint         NULL
    , [PhysicalReads]                bigint         NULL
    , [PageServerReads]              bigint         NULL
    , [ReadAheadReads]               bigint         NULL
    , [PageServerReadAheadReads]     bigint         NULL
    , [LobLogicalReads]              bigint         NULL
    , [LobPhysicalReads]             bigint         NULL
    , [LobPageServerReads]           bigint         NULL
    , [LobReadAheadReads]            bigint         NULL
    , [LobPageServerReadAheadReads]  bigint         NULL
    , [LanguageDetected]             varchar(16)     NOT NULL
    , [ParseStatus]                  varchar(40)     NOT NULL
    , [RawLine]                      nvarchar(4000)  NULL
)
AS
BEGIN
    DECLARE @Text nvarchar(max)=COALESCE(@StatisticsIoText,N'');
    DECLARE @Language varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@StatisticsLanguage,'AUTO'))));
    IF @Language NOT IN ('AUTO','EN','DE') SET @Language='AUTO';

    SET @Text=REPLACE(REPLACE(@Text,NCHAR(13)+NCHAR(10),NCHAR(10)),NCHAR(13),NCHAR(10));

    DECLARE @Labels TABLE
    (
          [LabelOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [MetricCode] varchar(40) NOT NULL
        , [LabelText] nvarchar(100) NOT NULL
    );

    INSERT @Labels([MetricCode],[LabelText])
    VALUES
      ('SCAN_COUNT',N'scan count '),('SCAN_COUNT',N'scananzahl '),
      ('LOGICAL_READS',N'logical reads '),('LOGICAL_READS',N'logische lesevorgänge '),
      ('PHYSICAL_READS',N'physical reads '),('PHYSICAL_READS',N'physische lesevorgänge '),
      ('PAGE_SERVER_READS',N'page server reads '),('PAGE_SERVER_READS',N'seitenserver-lesevorgänge '),
      ('READ_AHEAD_READS',N'read-ahead reads '),('READ_AHEAD_READS',N'vorausgelesene seiten '),('READ_AHEAD_READS',N'lesevorgänge im voraus '),
      ('PAGE_SERVER_READ_AHEAD_READS',N'page server read-ahead reads '),('PAGE_SERVER_READ_AHEAD_READS',N'seitenserver-vorauslesevorgänge '),
      ('LOB_LOGICAL_READS',N'lob logical reads '),('LOB_LOGICAL_READS',N'logische lob-lesevorgänge '),
      ('LOB_PHYSICAL_READS',N'lob physical reads '),('LOB_PHYSICAL_READS',N'physische lob-lesevorgänge '),
      ('LOB_PAGE_SERVER_READS',N'lob page server reads '),('LOB_PAGE_SERVER_READS',N'lob-seitenserver-lesevorgänge '),
      ('LOB_READ_AHEAD_READS',N'lob read-ahead reads '),('LOB_READ_AHEAD_READS',N'lob-vorauslesevorgänge '),
      ('LOB_PAGE_SERVER_READ_AHEAD_READS',N'lob page server read-ahead reads '),('LOB_PAGE_SERVER_READ_AHEAD_READS',N'lob-seitenserver-vorauslesevorgänge ');

    DECLARE
          @Start int=1
        , @Next int
        , @Length int=LEN(@Text)
        , @Line nvarchar(4000)
        , @LowerLine nvarchar(4000)
        , @MessageOrdinal int=0
        , @ObjectOrdinal int=0
        , @Quote1 int
        , @Quote2 int
        , @ObjectName nvarchar(512)
        , @Detected varchar(16)
        , @MetricOrdinal int
        , @MetricMax int=(SELECT MAX([LabelOrdinal]) FROM @Labels)
        , @MetricCode varchar(40)
        , @LabelText nvarchar(100)
        , @MetricPosition int
        , @NumericText nvarchar(100)
        , @NumericTextLength int
        , @MetricValue bigint
        , @ScanCount bigint
        , @LogicalReads bigint
        , @PhysicalReads bigint
        , @PageServerReads bigint
        , @ReadAheadReads bigint
        , @PageServerReadAheadReads bigint
        , @LobLogicalReads bigint
        , @LobPhysicalReads bigint
        , @LobPageServerReads bigint
        , @LobReadAheadReads bigint
        , @LobPageServerReadAheadReads bigint;

    WHILE @Start<=@Length+1
    BEGIN
        SET @Next=CHARINDEX(NCHAR(10),@Text,@Start);
        IF @Next=0 SET @Next=@Length+1;
        SET @Line=LTRIM(RTRIM(SUBSTRING(@Text,@Start,@Next-@Start)));
        SET @Start=@Next+1;
        IF @Line=N'' CONTINUE;

        SET @LowerLine=LOWER(@Line);
        IF CHARINDEX(N'scan count ',@LowerLine)=0
           AND CHARINDEX(N'scananzahl ',@LowerLine)=0
            CONTINUE;

        SET @MessageOrdinal+=1;
        SET @ObjectOrdinal+=1;
        SET @Detected=CASE WHEN CHARINDEX(N'scananzahl ',@LowerLine)>0 THEN 'DE' ELSE 'EN' END;

        SELECT
              @ObjectName=NULL
            , @Quote1=CHARINDEX(N'''',@Line)
            , @Quote2=0
            , @ScanCount=NULL
            , @LogicalReads=NULL
            , @PhysicalReads=NULL
            , @PageServerReads=NULL
            , @ReadAheadReads=NULL
            , @PageServerReadAheadReads=NULL
            , @LobLogicalReads=NULL
            , @LobPhysicalReads=NULL
            , @LobPageServerReads=NULL
            , @LobReadAheadReads=NULL
            , @LobPageServerReadAheadReads=NULL;

        IF @Quote1>0 SET @Quote2=CHARINDEX(N'''',@Line,@Quote1+1);
        IF @Quote2>@Quote1 SET @ObjectName=SUBSTRING(@Line,@Quote1+1,@Quote2-@Quote1-1);

        SET @MetricOrdinal=1;
        WHILE @MetricOrdinal<=@MetricMax
        BEGIN
            SELECT @MetricCode=[MetricCode],@LabelText=[LabelText]
            FROM @Labels
            WHERE [LabelOrdinal]=@MetricOrdinal;

            SET @MetricPosition=CHARINDEX(@LabelText,@LowerLine);
            IF @MetricPosition>0
            BEGIN
                SET @NumericText=LTRIM(SUBSTRING(@LowerLine,@MetricPosition+LEN(@LabelText),100));
                SET @NumericTextLength=1;
                WHILE @NumericTextLength<=LEN(@NumericText)
                  AND SUBSTRING(@NumericText,@NumericTextLength,1) LIKE N'[0-9-]'
                    SET @NumericTextLength+=1;
                SET @MetricValue=TRY_CONVERT(bigint,NULLIF(LEFT(@NumericText,@NumericTextLength-1),N''));

                IF @MetricCode='SCAN_COUNT' AND @ScanCount IS NULL SET @ScanCount=@MetricValue;
                IF @MetricCode='LOGICAL_READS' AND @LogicalReads IS NULL SET @LogicalReads=@MetricValue;
                IF @MetricCode='PHYSICAL_READS' AND @PhysicalReads IS NULL SET @PhysicalReads=@MetricValue;
                IF @MetricCode='PAGE_SERVER_READS' AND @PageServerReads IS NULL SET @PageServerReads=@MetricValue;
                IF @MetricCode='READ_AHEAD_READS' AND @ReadAheadReads IS NULL SET @ReadAheadReads=@MetricValue;
                IF @MetricCode='PAGE_SERVER_READ_AHEAD_READS' AND @PageServerReadAheadReads IS NULL SET @PageServerReadAheadReads=@MetricValue;
                IF @MetricCode='LOB_LOGICAL_READS' AND @LobLogicalReads IS NULL SET @LobLogicalReads=@MetricValue;
                IF @MetricCode='LOB_PHYSICAL_READS' AND @LobPhysicalReads IS NULL SET @LobPhysicalReads=@MetricValue;
                IF @MetricCode='LOB_PAGE_SERVER_READS' AND @LobPageServerReads IS NULL SET @LobPageServerReads=@MetricValue;
                IF @MetricCode='LOB_READ_AHEAD_READS' AND @LobReadAheadReads IS NULL SET @LobReadAheadReads=@MetricValue;
                IF @MetricCode='LOB_PAGE_SERVER_READ_AHEAD_READS' AND @LobPageServerReadAheadReads IS NULL SET @LobPageServerReadAheadReads=@MetricValue;
            END;
            SET @MetricOrdinal+=1;
        END;

        INSERT @Result
        (
              [StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],[ObjectDisplayName]
            , [ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads]
            , [ReadAheadReads],[PageServerReadAheadReads]
            , [LobLogicalReads],[LobPhysicalReads],[LobPageServerReads]
            , [LobReadAheadReads],[LobPageServerReadAheadReads]
            , [LanguageDetected],[ParseStatus],[RawLine]
        )
        VALUES
        (
              NULL,@MessageOrdinal,@ObjectOrdinal,@ObjectName
            , @ScanCount,@LogicalReads,@PhysicalReads,@PageServerReads
            , @ReadAheadReads,@PageServerReadAheadReads
            , @LobLogicalReads,@LobPhysicalReads,@LobPageServerReads
            , @LobReadAheadReads,@LobPageServerReadAheadReads
            , @Detected
            , CASE WHEN @ObjectName IS NOT NULL AND @ScanCount IS NOT NULL AND @LogicalReads IS NOT NULL
                   THEN 'PARSED' ELSE 'PARSED_PARTIAL' END
            , LEFT(@Line,4000)
        );
    END;

    RETURN;
END;
GO
-- END SOURCE: Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql

-- BEGIN SOURCE: Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql
/*
===============================================================================
Objekt       : monitor.TVF_ParseStatisticsTimeText
Version      : 1.0.1
Stand        : 2026-07-21
Typ          : Multi-statement Table-valued Function
Zweck        : Parst bereits vorliegenden SET STATISTICS TIME-Meldungstext ohne
               SQL auszuführen. Parse-/Compile- und Execution-Blöcke bleiben
               getrennt; mehrdeutige Formate werden als partiell markiert.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseStatisticsTimeText]
(
      @StatisticsTimeText nvarchar(max)
    , @StatisticsLanguage varchar(16) = 'AUTO'
)
RETURNS @Result TABLE
(
      [StatementOrdinal] int           NULL
    , [MessageOrdinal]   int           NOT NULL
    , [TimeCategory]     varchar(24)   NOT NULL
    , [CpuMs]            bigint        NULL
    , [ElapsedMs]        bigint        NULL
    , [LanguageDetected] varchar(16)   NOT NULL
    , [ParseStatus]      varchar(40)   NOT NULL
    , [RawLine]          nvarchar(4000) NULL
)
AS
BEGIN
    DECLARE @Text nvarchar(max)=COALESCE(@StatisticsTimeText,N'');
    SET @Text=REPLACE(REPLACE(@Text,NCHAR(13)+NCHAR(10),NCHAR(10)),NCHAR(13),NCHAR(10));

    DECLARE
          @Start int=1
        , @Next int
        , @Length int=LEN(@Text)
        , @Line nvarchar(4000)
        , @LowerLine nvarchar(4000)
        , @Category varchar(24)='UNKNOWN'
        , @Detected varchar(16)='EN'
        , @MessageOrdinal int=0
        , @CpuPosition int
        , @ElapsedPosition int
        , @NumericText nvarchar(100)
        , @NumericTextLength int
        , @CpuMs bigint
        , @ElapsedMs bigint;

    WHILE @Start<=@Length+1
    BEGIN
        SET @Next=CHARINDEX(NCHAR(10),@Text,@Start);
        IF @Next=0 SET @Next=@Length+1;
        SET @Line=LTRIM(RTRIM(SUBSTRING(@Text,@Start,@Next-@Start)));
        SET @Start=@Next+1;
        IF @Line=N'' CONTINUE;

        SET @LowerLine=LOWER(@Line);

        IF CHARINDEX(N'parse and compile time',@LowerLine)>0
           OR CHARINDEX(N'analyse- und kompilierzeit',@LowerLine)>0
           OR CHARINDEX(N'parse- und kompilierzeit',@LowerLine)>0
        BEGIN
            SET @Category='PARSE_COMPILE';
            SET @Detected=CASE WHEN CHARINDEX(N'compile time',@LowerLine)>0 THEN 'EN' ELSE 'DE' END;
            IF CHARINDEX(N'cpu time =',@LowerLine)=0 AND CHARINDEX(N'cpu-zeit =',@LowerLine)=0 CONTINUE;
        END;

        IF CHARINDEX(N'execution times',@LowerLine)>0
           OR CHARINDEX(N'ausführungszeiten',@LowerLine)>0
           OR CHARINDEX(N'ausführungszeit',@LowerLine)>0
        BEGIN
            SET @Category='EXECUTION';
            SET @Detected=CASE WHEN CHARINDEX(N'execution times',@LowerLine)>0 THEN 'EN' ELSE 'DE' END;
            IF CHARINDEX(N'cpu time =',@LowerLine)=0 AND CHARINDEX(N'cpu-zeit =',@LowerLine)=0 CONTINUE;
        END;

        SET @CpuPosition=CHARINDEX(N'cpu time =',@LowerLine);
        IF @CpuPosition=0 SET @CpuPosition=CHARINDEX(N'cpu-zeit =',@LowerLine);
        SET @ElapsedPosition=CHARINDEX(N'elapsed time =',@LowerLine);
        IF @ElapsedPosition=0 SET @ElapsedPosition=CHARINDEX(N'verstrichene zeit =',@LowerLine);

        IF @CpuPosition=0 AND @ElapsedPosition=0 CONTINUE;

        SELECT @CpuMs=NULL,@ElapsedMs=NULL;
        IF @CpuPosition>0
        BEGIN
            SET @NumericText=LTRIM(SUBSTRING(@LowerLine,@CpuPosition+CASE WHEN SUBSTRING(@LowerLine,@CpuPosition,8)=N'cpu time' THEN LEN(N'cpu time =') ELSE LEN(N'cpu-zeit =') END,100));
            SET @NumericTextLength=1;
            WHILE @NumericTextLength<=LEN(@NumericText)
              AND SUBSTRING(@NumericText,@NumericTextLength,1) LIKE N'[0-9-]'
                SET @NumericTextLength+=1;
            SET @CpuMs=TRY_CONVERT(bigint,NULLIF(LEFT(@NumericText,@NumericTextLength-1),N''));
        END;

        IF @ElapsedPosition>0
        BEGIN
            SET @NumericText=LTRIM(SUBSTRING(@LowerLine,@ElapsedPosition+CASE WHEN SUBSTRING(@LowerLine,@ElapsedPosition,7)=N'elapsed' THEN LEN(N'elapsed time =') ELSE LEN(N'verstrichene zeit =') END,100));
            SET @NumericTextLength=1;
            WHILE @NumericTextLength<=LEN(@NumericText)
              AND SUBSTRING(@NumericText,@NumericTextLength,1) LIKE N'[0-9-]'
                SET @NumericTextLength+=1;
            SET @ElapsedMs=TRY_CONVERT(bigint,NULLIF(LEFT(@NumericText,@NumericTextLength-1),N''));
        END;

        SET @MessageOrdinal+=1;
        INSERT @Result
        (
              [StatementOrdinal],[MessageOrdinal],[TimeCategory]
            , [CpuMs],[ElapsedMs],[LanguageDetected],[ParseStatus],[RawLine]
        )
        VALUES
        (
              NULL,@MessageOrdinal,@Category,@CpuMs,@ElapsedMs,@Detected
            , CASE WHEN @Category<>'UNKNOWN' AND @CpuMs IS NOT NULL AND @ElapsedMs IS NOT NULL
                   THEN 'PARSED' ELSE 'PARSED_PARTIAL' END
            , LEFT(@Line,4000)
        );
    END;

    RETURN;
END;
GO
-- END SOURCE: Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql

-- BEGIN SOURCE: Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql
/*
===============================================================================
Objekt       : monitor.TVF_ExecutionPlanObjectReferences
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Extrahiert statement- und operatorbezogene Objekt-/Indexreferenzen
               ausschließlich aus übergebenem Showplan-XML. Keine Katalogzugriffe.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanObjectReferences]
(
      @PlanXml     xml
    , @StatementId int = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH [StatementsBase] AS
    (
        SELECT
              [StatementXml]=[s].[n].query('.')
            , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
            , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
            , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'')
        FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
    ),
    [Statements] AS
    (
        SELECT
              [StatementOrdinal]=CONVERT(int,ROW_NUMBER() OVER
                (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
            , [StatementId]
            , [StatementCompId]
            , [StatementXml]
        FROM [StatementsBase]
        WHERE @StatementId IS NULL OR [StatementId]=@StatementId
    ),
    [AccessObjectsRaw] AS
    (
        SELECT
              [st].[StatementOrdinal]
            , [st].[StatementId]
            , [st].[StatementCompId]
            , [NodeId]=TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , [PhysicalOp]=NULLIF([r].[n].value('string((@PhysicalOp)[1])','nvarchar(128)'),N'')
            , [DatabaseRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Database)[1])','nvarchar(256)'),N'')
            , [SchemaRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Schema)[1])','nvarchar(256)'),N'')
            , [ObjectRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Table)[1])','nvarchar(256)'),N'')
            , [IndexRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Index)[1])','nvarchar(256)'),N'')
            , [AliasRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Alias)[1])','nvarchar(256)'),N'')
            , [StorageType]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Storage)[1])','nvarchar(128)'),N'')
            , [PlanObjectId]=TRY_CONVERT(int,NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@ObjectId)[1])','nvarchar(50)'),N''))
            , [PlanIndexId]=CONVERT(int,NULL)
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        WHERE [r].[n].exist('./*/*[local-name(.)="Object"]')=1
    ),
    [AccessObjects] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],[PhysicalOp]
            , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                                  THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
            , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
            , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
            , [IndexName]=CASE WHEN LEFT([IndexRaw],1)=N'[' AND RIGHT([IndexRaw],1)=N']'
                               THEN REPLACE(SUBSTRING([IndexRaw],2,LEN([IndexRaw])-2),N']]',N']') ELSE [IndexRaw] END
            , [AliasName]=CASE WHEN LEFT([AliasRaw],1)=N'[' AND RIGHT([AliasRaw],1)=N']'
                               THEN REPLACE(SUBSTRING([AliasRaw],2,LEN([AliasRaw])-2),N']]',N']') ELSE [AliasRaw] END
            , [StorageType],[PlanObjectId],[PlanIndexId]
        FROM [AccessObjectsRaw]
    ),
    [MissingObjectsRaw] AS
    (
        SELECT
              [st].[StatementOrdinal]
            , [st].[StatementId]
            , [st].[StatementCompId]
            , [DatabaseRaw]=NULLIF([m].[n].value('string((@Database)[1])','nvarchar(256)'),N'')
            , [SchemaRaw]=NULLIF([m].[n].value('string((@Schema)[1])','nvarchar(256)'),N'')
            , [ObjectRaw]=NULLIF([m].[n].value('string((@Table)[1])','nvarchar(256)'),N'')
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="MissingIndex"]') AS [m]([n])
    ),
    [MissingObjects] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId]
            , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                                  THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
            , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
            , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
        FROM [MissingObjectsRaw]
    ),
    [AllReferences] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
            , [ReferenceType]=CONVERT(varchar(40),CASE
                  WHEN [ObjectName] LIKE N'#%' THEN 'TEMPORARY_OBJECT'
                  WHEN [ObjectName] LIKE N'@%' THEN 'TABLE_VARIABLE'
                  WHEN [IndexName] IS NOT NULL THEN 'INDEX'
                  ELSE 'TABLE' END)
            , [ReferenceSource]=CONVERT(varchar(40),CASE
                  WHEN [PhysicalOp] LIKE N'%Update%' OR [PhysicalOp] LIKE N'%Insert%'
                    OR [PhysicalOp] LIKE N'%Delete%' OR [PhysicalOp]=N'Merge'
                    THEN 'DML_TARGET' ELSE 'ACCESS_PATH' END)
            , [DatabaseName],[SchemaName],[ObjectName],[IndexName],[AliasName],[StorageType]
            , [PlanObjectId],[PlanIndexId]
            , [IsTemporaryObject]=CONVERT(bit,CASE WHEN [ObjectName] LIKE N'#%' OR [DatabaseName]=N'tempdb' THEN 1 ELSE 0 END)
            , [IsTableVariable]=CONVERT(bit,CASE WHEN [ObjectName] LIKE N'@%' THEN 1 ELSE 0 END)
            , [IsRemoteObject]=CONVERT(bit,0)
            , [IsDmlTarget]=CONVERT(bit,CASE
                  WHEN [PhysicalOp] LIKE N'%Update%' OR [PhysicalOp] LIKE N'%Insert%'
                    OR [PhysicalOp] LIKE N'%Delete%' OR [PhysicalOp]=N'Merge'
                    THEN 1 ELSE 0 END)
            , [ResolutionCapability]=CONVERT(varchar(40),CASE
                  WHEN [ObjectName] LIKE N'#%' THEN 'TEMP_OBJECT_CONTEXT_REQUIRED'
                  WHEN [ObjectName] LIKE N'@%' THEN 'PLAN_ONLY'
                  WHEN [DatabaseName] IS NULL OR [SchemaName] IS NULL OR [ObjectName] IS NULL THEN 'INCOMPLETE_REFERENCE'
                  ELSE 'CATALOG_RESOLVABLE' END)
            , [SourceElement]=CONVERT(nvarchar(128),N'Object')
        FROM [AccessObjects]
        WHERE [ObjectName] IS NOT NULL

        UNION ALL

        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],NULL
            , 'TABLE','MISSING_INDEX',[DatabaseName],[SchemaName],[ObjectName]
            , NULL,NULL,NULL,NULL,NULL,0,0,0,0
            , CASE WHEN [DatabaseName] IS NULL OR [SchemaName] IS NULL OR [ObjectName] IS NULL
                   THEN 'INCOMPLETE_REFERENCE' ELSE 'CATALOG_RESOLVABLE' END
            , N'MissingIndex'
        FROM [MissingObjects]
        WHERE [ObjectName] IS NOT NULL
    )
    SELECT
          [ReferenceOrdinal]=CONVERT(bigint,ROW_NUMBER() OVER
            (ORDER BY [StatementOrdinal],COALESCE([NodeId],2147483647),[ReferenceSource],COALESCE([DatabaseName],N''),COALESCE([SchemaName],N''),COALESCE([ObjectName],N''),COALESCE([IndexName],N'')))
        , [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
        , [ReferenceType],[ReferenceSource],[DatabaseName],[SchemaName],[ObjectName]
        , [IndexName],[AliasName],[StorageType],[PlanObjectId],[PlanIndexId]
        , [IsTemporaryObject],[IsTableVariable],[IsRemoteObject],[IsDmlTarget]
        , [ResolutionCapability],[SourceElement]
    FROM [AllReferences]
);
GO
-- END SOURCE: Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql

-- BEGIN SOURCE: Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql
/*
===============================================================================
Objekt       : monitor.TVF_ExecutionPlanStatisticsUsage
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Extrahiert OptimizerStatsUsage je Statement aus Showplan-XML.
               Die Werte beschreiben den im Plan gespeicherten Compilezeitstand.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanStatisticsUsage]
(
      @PlanXml     xml
    , @StatementId int = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH [StatementsBase] AS
    (
        SELECT
              [StatementXml]=[s].[n].query('.')
            , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
            , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
            , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'')
        FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
    ),
    [Statements] AS
    (
        SELECT
              [StatementOrdinal]=CONVERT(int,ROW_NUMBER() OVER
                (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
            , [StatementId],[StatementCompId],[StatementXml]
        FROM [StatementsBase]
        WHERE @StatementId IS NULL OR [StatementId]=@StatementId
    ),
    [Raw] AS
    (
        SELECT
              [st].[StatementOrdinal],[st].[StatementId],[st].[StatementCompId]
            , [DatabaseRaw]=NULLIF([i].[n].value('string((@Database)[1])','nvarchar(256)'),N'')
            , [SchemaRaw]=NULLIF([i].[n].value('string((@Schema)[1])','nvarchar(256)'),N'')
            , [ObjectRaw]=NULLIF([i].[n].value('string((@Table)[1])','nvarchar(256)'),N'')
            , [StatisticsRaw]=NULLIF([i].[n].value('string((@Statistics)[1])','nvarchar(256)'),N'')
            , [LastUpdateAtCompile]=TRY_CONVERT(datetime2(7),NULLIF([i].[n].value('string((@LastUpdate)[1])','nvarchar(100)'),N''))
            , [ModificationCountAtCompile]=TRY_CONVERT(bigint,NULLIF([i].[n].value('string((@ModificationCount)[1])','nvarchar(100)'),N''))
            , [SamplingPercentAtCompile]=TRY_CONVERT(decimal(19,6),NULLIF([i].[n].value('string((@SamplingPercent)[1])','nvarchar(100)'),N''))
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="OptimizerStatsUsage"]/*[local-name(.)="StatisticsInfo"]') AS [i]([n])
    )
    SELECT
          [StatisticsUsageOrdinal]=CONVERT(bigint,ROW_NUMBER() OVER
            (ORDER BY [StatementOrdinal],COALESCE([DatabaseRaw],N''),COALESCE([SchemaRaw],N''),COALESCE([ObjectRaw],N''),COALESCE([StatisticsRaw],N'')))
        , [StatementOrdinal],[StatementId],[StatementCompId]
        , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                              THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
        , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
        , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
        , [StatisticsName]=CASE WHEN LEFT([StatisticsRaw],1)=N'[' AND RIGHT([StatisticsRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([StatisticsRaw],2,LEN([StatisticsRaw])-2),N']]',N']') ELSE [StatisticsRaw] END
        , [LastUpdateAtCompile],[ModificationCountAtCompile],[SamplingPercentAtCompile]
        , [SourceElement]=CONVERT(nvarchar(128),N'OptimizerStatsUsage/StatisticsInfo')
        , [ParseStatus]=CONVERT(varchar(40),CASE
              WHEN [ObjectRaw] IS NOT NULL AND [StatisticsRaw] IS NOT NULL THEN 'AVAILABLE'
              ELSE 'INCOMPLETE_REFERENCE' END)
    FROM [Raw]
);
GO
-- END SOURCE: Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql

-- BEGIN SOURCE: Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql
/*
===============================================================================
Objekt       : monitor.TVF_ExecutionPlanColumnReferences
Version      : 1.0.2
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Normalisiert Spaltenrollen aus Showplan-XML für zielgerichtete
               Index- und Statistikauflösung. Keine Katalogzugriffe.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanColumnReferences]
(
      @PlanXml     xml
    , @StatementId int = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH [StatementsBase] AS
    (
        SELECT
              [StatementXml]=[s].[n].query('.')
            , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
            , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
            , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'')
        FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
    ),
    [Statements] AS
    (
        SELECT
              [StatementOrdinal]=CONVERT(int,ROW_NUMBER() OVER
                (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
            , [StatementId],[StatementCompId],[StatementXml]
        FROM [StatementsBase]
        WHERE @StatementId IS NULL OR [StatementId]=@StatementId
    ),
    [RelOps] AS
    (
        SELECT
              [st].[StatementOrdinal],[st].[StatementId],[st].[StatementCompId]
            , [NodeId]=TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , [RelOpXml]=[r].[n].query('.')
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
    ),
    [Roles] AS
    (
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               CONVERT(varchar(40),'SEEK') [ColumnUsage],CONVERT(varchar(80),'SEEK_PREDICATE') [ExpressionContext],
               [ColumnReferenceXml]=[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('./*/*[local-name(.)="SeekPredicates"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'RESIDUAL','PREDICATE',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('./*/*[local-name(.)="Predicate"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'JOIN','JOIN_KEY_OR_PREDICATE',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('./*/*[local-name(.)="HashKeysBuild" or local-name(.)="HashKeysProbe" or local-name(.)="InnerSideJoinColumns" or local-name(.)="OuterSideJoinColumns" or local-name(.)="OuterReferences"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'ORDER_BY','ORDER_REQUIREMENT',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('./*/*[local-name(.)="OrderBy" or local-name(.)="SortKeys"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'GROUP_BY','GROUP_REQUIREMENT',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('./*/*[local-name(.)="GroupBy"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'OUTPUT','OUTPUT_LIST',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('./*[local-name(.)="OutputList"]/*[local-name(.)="ColumnReference"]') AS [c]([n])
    ),
    [Raw] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
            , [ColumnUsage],[ExpressionContext]
            , [DatabaseRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Database)[1])','nvarchar(256)'),N'')
            , [SchemaRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Schema)[1])','nvarchar(256)'),N'')
            , [ObjectRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Table)[1])','nvarchar(256)'),N'')
            , [AliasRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Alias)[1])','nvarchar(256)'),N'')
            , [ColumnRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Column)[1])','nvarchar(256)'),N'')
        FROM [Roles]
    )
    SELECT
          [ColumnReferenceOrdinal]=CONVERT(bigint,ROW_NUMBER() OVER
            (ORDER BY [StatementOrdinal],COALESCE([NodeId],2147483647),[ColumnUsage],COALESCE([ObjectRaw],N''),COALESCE([ColumnRaw],N'')))
        , [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
        , [ColumnUsage],[ExpressionContext]
        , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                              THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
        , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
        , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
        , [AliasName]=CASE WHEN LEFT([AliasRaw],1)=N'[' AND RIGHT([AliasRaw],1)=N']'
                           THEN REPLACE(SUBSTRING([AliasRaw],2,LEN([AliasRaw])-2),N']]',N']') ELSE [AliasRaw] END
        , [ColumnName]=CASE WHEN LEFT([ColumnRaw],1)=N'[' AND RIGHT([ColumnRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([ColumnRaw],2,LEN([ColumnRaw])-2),N']]',N']') ELSE [ColumnRaw] END
        , [IsSeekColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='SEEK' THEN 1 ELSE 0 END)
        , [IsResidualPredicateColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='RESIDUAL' THEN 1 ELSE 0 END)
        , [IsJoinColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='JOIN' THEN 1 ELSE 0 END)
        , [IsGroupByColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='GROUP_BY' THEN 1 ELSE 0 END)
        , [IsOrderByColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='ORDER_BY' THEN 1 ELSE 0 END)
        , [IsOutputColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='OUTPUT' THEN 1 ELSE 0 END)
        , [IsPartitionColumn]=CONVERT(bit,0)
    FROM [Raw]
    WHERE [ColumnRaw] IS NOT NULL
);
GO
-- END SOURCE: Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql

-- BEGIN SOURCE: Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql
/*
===============================================================================
Objekt       : monitor.InternalCollectExecutionPlanMetadata
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Ermittelt aus einem Plan zielgerichtet aktuelle Objekt-, Index-
               und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung.
               Histogrammrohwerte verbleiben ausschließlich in lokalen Temp-
               Tabellen des aufrufenden Evidenzgenerators.
Voraussetzung: Der Aufrufer legt #CreateExecutionEvidenceJson_StatisticsCurrent, #CreateExecutionEvidenceJson_HistogramSteps,
               #CreateExecutionEvidenceJson_HistogramSummary, #CreateExecutionEvidenceJson_PredicateHistogramMappings und
               #CreateExecutionEvidenceJson_CollectionStatus mit dem dokumentierten Schema an.
Locking      : Katalogabfragen mit LOCK_TIMEOUT; kein Zugriff auf Benutzerdaten.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalCollectExecutionPlanMetadata]
      @PlanXml                      xml
    , @StatistikEvidenzModus        varchar(16)    = 'USED'
    , @HistogrammModus              varchar(16)    = 'NONE'
    , @QuellumgebungBestaetigt      bit            = 0
    , @MitPredicateHistogramMap     bit            = 1
    , @MaxStatistiken               int            = 100
    , @MaxHistogrammSchritte        int            = 20000
    , @LockTimeoutMs                int            = 0
    , @HighImpactConfirmed          bit            = 0
    , @StatusCodeOut                varchar(40)     = NULL OUTPUT
    , @IsPartialOut                 bit             = NULL OUTPUT
    , @ErrorNumberOut               int             = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT
          @StatistikEvidenzModus=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'USED'))))
        , @HistogrammModus=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))))
        , @StatusCodeOut='AVAILABLE'
        , @IsPartialOut=0
        , @ErrorNumberOut=NULL
        , @ErrorMessageOut=NULL;

    IF @PlanXml IS NULL
       OR @StatistikEvidenzModus NOT IN ('USED','RELEVANT','OBJECT_ALL')
       OR @HistogrammModus NOT IN ('NONE','SUMMARY','STEPS')
       OR @QuellumgebungBestaetigt<>1
       OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Plan-, Modus-, Bestätigungs-, Mengen- oder Lock-Timeout-Parameter.';
        RETURN;
    END;

    BEGIN TRY
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_StatisticsCurrent];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_HistogramSteps];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_HistogramSummary];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_PredicateHistogramMappings];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_CollectionStatus];
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut='INTERNAL_ERROR',@IsPartialOut=1,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=N'Die erwarteten lokalen Evidenz-Temp-Tabellen fehlen oder besitzen ein unpassendes Schema.';
        RETURN;
    END CATCH;

    IF @StatistikEvidenzModus IN ('RELEVANT','OBJECT_ALL') OR @HistogrammModus='STEPS'
    BEGIN
        IF @HighImpactConfirmed<>1
        BEGIN
            SELECT @StatusCodeOut='HIGH_IMPACT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
                   @ErrorMessageOut=N'Die angeforderte breite Statistik- oder Histogrammanreicherung benötigt @HighImpactConfirmed=1.';
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM [sys].[procedures] AS [p] WITH (NOLOCK)
            JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
              ON [s].[schema_id]=[p].[schema_id]
            WHERE [s].[name]=N'monitor'
              AND [p].[name]=N'InternalCheckAnalysisPath'
        )
        BEGIN
            DECLARE @GateStatus varchar(40),@GateMessage nvarchar(2048);
            EXEC [sys].[sp_executesql]
                  N'EXEC [monitor].[InternalCheckAnalysisPath]
                          @AnalysisClass=''CATALOG_DEEP'',
                          @HighImpactConfirmed=@HighImpactConfirmed,
                          @StatusCode=@StatusCode OUTPUT,
                          @ErrorMessage=@ErrorMessage OUTPUT;'
                , N'@HighImpactConfirmed bit,@StatusCode varchar(40) OUTPUT,@ErrorMessage nvarchar(2048) OUTPUT'
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCode=@GateStatus OUTPUT
                , @ErrorMessage=@GateMessage OUTPUT;
            IF @GateStatus<>'AVAILABLE'
            BEGIN
                SELECT @StatusCodeOut=@GateStatus,@IsPartialOut=1,@ErrorMessageOut=@GateMessage;
                RETURN;
            END;
        END;
    END;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    BEGIN TRY
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_ObjectReferences]
    (
          [DatabaseName] sysname NOT NULL
        , [SchemaName] sysname NOT NULL
        , [ObjectName] sysname NOT NULL
        , PRIMARY KEY ([DatabaseName],[SchemaName],[ObjectName])
    );
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_RelevantColumns]
    (
          [DatabaseName] sysname NOT NULL
        , [SchemaName] sysname NOT NULL
        , [ObjectName] sysname NOT NULL
        , [ColumnName] sysname NOT NULL
        , PRIMARY KEY ([DatabaseName],[SchemaName],[ObjectName],[ColumnName])
    );
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
    (
          [CandidateId] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname NOT NULL
        , [SchemaName] sysname NOT NULL
        , [ObjectName] sysname NOT NULL
        , [StatisticsName] sysname NOT NULL
        , [CandidateSource] varchar(40) NOT NULL
        , UNIQUE ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName])
    );
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_PredicateValues]
    (
          [PredicateReferenceId] bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [StatementOrdinal] int NOT NULL
        , [NodeId] int NULL
        , [DatabaseName] sysname NULL
        , [SchemaName] sysname NULL
        , [ObjectName] sysname NULL
        , [ColumnName] sysname NULL
        , [PredicateKind] varchar(40) NULL
        , [ParameterName] nvarchar(256) NULL
        , [CompiledValueRaw] nvarchar(4000) NULL
        , [RuntimeValueRaw] nvarchar(4000) NULL
        , [CompiledValueNormalized] nvarchar(4000) NULL
        , [RuntimeValueNormalized] nvarchar(4000) NULL
    );

    INSERT [#InternalCollectExecutionPlanMetadata_ObjectReferences]([DatabaseName],[SchemaName],[ObjectName])
    SELECT [DatabaseName],[SchemaName],[ObjectName]
    FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml,NULL)
    WHERE [ResolutionCapability]='CATALOG_RESOLVABLE'
      AND [DatabaseName] IS NOT NULL AND [SchemaName] IS NOT NULL AND [ObjectName] IS NOT NULL
    GROUP BY [DatabaseName],[SchemaName],[ObjectName];

    INSERT [#InternalCollectExecutionPlanMetadata_RelevantColumns]([DatabaseName],[SchemaName],[ObjectName],[ColumnName])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[ColumnName]
    FROM [monitor].[TVF_ExecutionPlanColumnReferences](@PlanXml,NULL)
    WHERE [ColumnUsage] IN ('SEEK','RESIDUAL','JOIN','ORDER_BY','GROUP_BY')
      AND [DatabaseName] IS NOT NULL AND [SchemaName] IS NOT NULL
      AND [ObjectName] IS NOT NULL AND [ColumnName] IS NOT NULL
    GROUP BY [DatabaseName],[SchemaName],[ObjectName],[ColumnName];

    INSERT [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
    ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[CandidateSource])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],'PLAN_USED'
    FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml,NULL)
    WHERE [ParseStatus]='AVAILABLE'
      AND [DatabaseName] IS NOT NULL AND [SchemaName] IS NOT NULL
      AND [ObjectName] IS NOT NULL AND [StatisticsName] IS NOT NULL
    GROUP BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName];

    DECLARE @Db sysname,@Schema sysname,@Object sysname,@Sql nvarchar(max);
    DECLARE [ObjectCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [DatabaseName],[SchemaName],[ObjectName]
        FROM [#InternalCollectExecutionPlanMetadata_ObjectReferences]
        ORDER BY [DatabaseName],[SchemaName],[ObjectName];

    IF @StatistikEvidenzModus IN ('RELEVANT','OBJECT_ALL')
    BEGIN
        OPEN [ObjectCursor];
        FETCH NEXT FROM [ObjectCursor] INTO @Db,@Schema,@Object;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                WHERE [d].[name]=@Db AND [d].[state]=0 AND HAS_DBACCESS([d].[name])=1
            )
            BEGIN
                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[CandidateSource])
SELECT @DatabaseName,[sc].[name],[o].[name],[st].[name],
       CASE WHEN @Mode=''OBJECT_ALL'' THEN ''OBJECT_ALL'' ELSE ''RELEVANT_LEADING_COLUMN'' END
FROM [sys].[schemas] AS [sc] WITH (NOLOCK)
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[sc].[schema_id]
JOIN [sys].[stats] AS [st] WITH (NOLOCK) ON [st].[object_id]=[o].[object_id]
WHERE [sc].[name]=@SchemaName AND [o].[name]=@ObjectName
  AND
  (
      @Mode=''OBJECT_ALL''
      OR EXISTS
      (
          SELECT 1
          FROM [sys].[stats_columns] AS [stc] WITH (NOLOCK)
          JOIN [sys].[columns] AS [c] WITH (NOLOCK)
            ON [c].[object_id]=[stc].[object_id] AND [c].[column_id]=[stc].[column_id]
          JOIN [#InternalCollectExecutionPlanMetadata_RelevantColumns] AS [rc]
            ON [rc].[DatabaseName]=@DatabaseName
           AND [rc].[SchemaName]=@SchemaName
           AND [rc].[ObjectName]=@ObjectName
           AND [rc].[ColumnName]=[c].[name]
          WHERE [stc].[object_id]=[st].[object_id]
            AND [stc].[stats_id]=[st].[stats_id]
            AND [stc].[stats_column_id]=1
      )
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [x]
      WHERE [x].[DatabaseName]=@DatabaseName
        AND [x].[SchemaName]=[sc].[name]
        AND [x].[ObjectName]=[o].[name]
        AND [x].[StatisticsName]=[st].[name]
  );';
                    EXEC [sys].[sp_executesql]
                          @Sql
                        , N'@DatabaseName sysname,@SchemaName sysname,@ObjectName sysname,@Mode varchar(16)'
                        , @DatabaseName=@Db,@SchemaName=@Schema,@ObjectName=@Object,@Mode=@StatistikEvidenzModus;
                END TRY
                BEGIN CATCH
                    INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
                    ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
                    VALUES(@Db,@Schema,@Object,NULL,'ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE());
                    SET @IsPartialOut=1;
                END CATCH;
            END
            ELSE
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
                ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
                VALUES(@Db,@Schema,@Object,NULL,'DATABASE_UNAVAILABLE',NULL,N'Die im Plan referenzierte Datenbank ist in der bestätigten aktuellen Umgebung nicht zugreifbar.');
                SET @IsPartialOut=1;
            END;

            FETCH NEXT FROM [ObjectCursor] INTO @Db,@Schema,@Object;
        END;
        CLOSE [ObjectCursor];
        DEALLOCATE [ObjectCursor];
    END;

    DELETE [c]
    FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [c]
    WHERE [c].[CandidateId] NOT IN
    (
        SELECT TOP (@MaxStatistiken) [CandidateId]
        FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
        ORDER BY CASE [CandidateSource] WHEN 'PLAN_USED' THEN 1 WHEN 'RELEVANT_LEADING_COLUMN' THEN 2 ELSE 3 END,
                 [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
    );

    DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [DatabaseName]
        FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
        GROUP BY [DatabaseName]
        ORDER BY [DatabaseName];

    OPEN [DatabaseCursor];
    FETCH NEXT FROM [DatabaseCursor] INTO @Db;
    WHILE @@FETCH_STATUS=0
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
            WHERE [d].[name]=@Db AND [d].[state]=0 AND HAS_DBACCESS([d].[name])=1
        )
        BEGIN TRY
            SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#CreateExecutionEvidenceJson_StatisticsCurrent]
(
      [DatabaseName],[SchemaName],[ObjectName],[ObjectId]
    , [StatisticsName],[StatisticsId],[IsIndexStatistics]
    , [IsAutoCreated],[IsUserCreated],[IsFiltered],[FilterDefinition]
    , [NoRecompute],[IsIncremental],[HasPersistedSample]
    , [LeadingColumnName],[LastUpdated],[Rows],[RowsSampled]
    , [SamplePercent],[Steps],[UnfilteredRows],[ModificationCounter]
    , [ModificationPercent],[PersistedSamplePercent],[CollectionStatus]
)
SELECT
      @DatabaseName,[sc].[name],[o].[name],[o].[object_id]
    , [st].[name],[st].[stats_id],CONVERT(bit,CASE WHEN [i].[index_id] IS NULL THEN 0 ELSE 1 END)
    , [st].[auto_created],[st].[user_created],[st].[has_filter],[st].[filter_definition]
    , [st].[no_recompute],[st].[is_incremental],[st].[has_persisted_sample]
    , [lc].[name],[sp].[last_updated],[sp].[rows],[sp].[rows_sampled]
    , CONVERT(decimal(19,6),CASE WHEN [sp].[rows]>0 THEN 100.0*[sp].[rows_sampled]/[sp].[rows] END)
    , [sp].[steps],[sp].[unfiltered_rows],[sp].[modification_counter]
    , CONVERT(decimal(19,6),CASE WHEN [sp].[rows]>0 THEN 100.0*[sp].[modification_counter]/[sp].[rows] END)
    , [sp].[persisted_sample_percent]
    , CASE WHEN [sp].[last_updated] IS NULL THEN ''PROPERTIES_UNAVAILABLE'' ELSE ''AVAILABLE'' END
FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [cs]
JOIN [sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[name]=[cs].[SchemaName]
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[sc].[schema_id] AND [o].[name]=[cs].[ObjectName]
JOIN [sys].[stats] AS [st] WITH (NOLOCK) ON [st].[object_id]=[o].[object_id] AND [st].[name]=[cs].[StatisticsName]
LEFT JOIN [sys].[indexes] AS [i] WITH (NOLOCK) ON [i].[object_id]=[st].[object_id] AND [i].[index_id]=[st].[stats_id]
LEFT JOIN [sys].[stats_columns] AS [stc] WITH (NOLOCK) ON [stc].[object_id]=[st].[object_id] AND [stc].[stats_id]=[st].[stats_id] AND [stc].[stats_column_id]=1
LEFT JOIN [sys].[columns] AS [lc] WITH (NOLOCK) ON [lc].[object_id]=[stc].[object_id] AND [lc].[column_id]=[stc].[column_id]
OUTER APPLY [sys].[dm_db_stats_properties]([st].[object_id],[st].[stats_id]) AS [sp]
WHERE [cs].[DatabaseName]=@DatabaseName
  AND NOT EXISTS
  (
      SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsCurrent] AS [x]
      WHERE [x].[DatabaseName]=@DatabaseName AND [x].[SchemaName]=[sc].[name]
        AND [x].[ObjectName]=[o].[name] AND [x].[StatisticsName]=[st].[name]
  );';
            EXEC [sys].[sp_executesql] @Sql,N'@DatabaseName sysname',@DatabaseName=@Db;

            IF @HistogrammModus<>'NONE'
            BEGIN
                DECLARE @ExistingSteps int=(SELECT COUNT(*) FROM [#CreateExecutionEvidenceJson_HistogramSteps]);
                DECLARE @RemainingSteps int=@MaxHistogrammSchritte-@ExistingSteps;
                IF @RemainingSteps>0
                BEGIN
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#CreateExecutionEvidenceJson_HistogramSteps]
(
      [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
    , [StatisticsId],[LeadingColumnName],[StepOrdinal],[RangeHighKeyRaw]
    , [RangeRows],[EqualRows],[DistinctRangeRows],[AverageRangeRows]
)
SELECT TOP (@RemainingSteps)
      @DatabaseName,[sc].[name],[o].[name],[st].[name]
    , [st].[stats_id],[lc].[name],[h].[step_number]
    , CONVERT(nvarchar(4000),[h].[range_high_key])
    , [h].[range_rows],[h].[equal_rows],[h].[distinct_range_rows],[h].[average_range_rows]
FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [cs]
JOIN [sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[name]=[cs].[SchemaName]
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[sc].[schema_id] AND [o].[name]=[cs].[ObjectName]
JOIN [sys].[stats] AS [st] WITH (NOLOCK) ON [st].[object_id]=[o].[object_id] AND [st].[name]=[cs].[StatisticsName]
LEFT JOIN [sys].[stats_columns] AS [stc] WITH (NOLOCK) ON [stc].[object_id]=[st].[object_id] AND [stc].[stats_id]=[st].[stats_id] AND [stc].[stats_column_id]=1
LEFT JOIN [sys].[columns] AS [lc] WITH (NOLOCK) ON [lc].[object_id]=[stc].[object_id] AND [lc].[column_id]=[stc].[column_id]
CROSS APPLY [sys].[dm_db_stats_histogram]([st].[object_id],[st].[stats_id]) AS [h]
WHERE [cs].[DatabaseName]=@DatabaseName
ORDER BY [cs].[CandidateId],[h].[step_number];';
                    EXEC [sys].[sp_executesql]
                          @Sql
                        , N'@DatabaseName sysname,@RemainingSteps int'
                        , @DatabaseName=@Db,@RemainingSteps=@RemainingSteps;
                END;
            END;
        END TRY
        BEGIN CATCH
            INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
            ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
            VALUES(@Db,NULL,NULL,NULL,CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());
            SET @IsPartialOut=1;
        END CATCH;

        FETCH NEXT FROM [DatabaseCursor] INTO @Db;
    END;
    CLOSE [DatabaseCursor];
    DEALLOCATE [DatabaseCursor];

    INSERT [#CreateExecutionEvidenceJson_HistogramSummary]
    (
          [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
        , [StatisticsId],[LeadingColumnName],[HistogramSteps]
        , [HistogramEstimatedRows],[MaxEqualRows],[MaxRangeRows]
        , [MaxStepRows],[DominantStepPercent],[TailStepRows],[TailStepPercent]
        , [CollectionStatus]
    )
    SELECT
          [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
        , [StatisticsId],MAX([LeadingColumnName]),COUNT(*)
        , SUM(COALESCE([RangeRows],0)+COALESCE([EqualRows],0))
        , MAX([EqualRows]),MAX([RangeRows])
        , MAX(COALESCE([RangeRows],0)+COALESCE([EqualRows],0))
        , CONVERT(decimal(19,6),100.0*MAX(COALESCE([RangeRows],0)+COALESCE([EqualRows],0))
            /NULLIF(SUM(COALESCE([RangeRows],0)+COALESCE([EqualRows],0)),0))
        , MAX(CASE WHEN [StepOrdinal]=[mx].[MaxStepOrdinal]
                   THEN COALESCE([RangeRows],0)+COALESCE([EqualRows],0) END)
        , CONVERT(decimal(19,6),100.0*MAX(CASE WHEN [StepOrdinal]=[mx].[MaxStepOrdinal]
                   THEN COALESCE([RangeRows],0)+COALESCE([EqualRows],0) END)
            /NULLIF(SUM(COALESCE([RangeRows],0)+COALESCE([EqualRows],0)),0))
        , 'AVAILABLE'
    FROM [#CreateExecutionEvidenceJson_HistogramSteps] AS [h]
    CROSS APPLY
    (
        SELECT MAX([StepOrdinal]) [MaxStepOrdinal]
        FROM [#CreateExecutionEvidenceJson_HistogramSteps] AS [h2]
        WHERE [h2].[DatabaseName]=[h].[DatabaseName]
          AND [h2].[SchemaName]=[h].[SchemaName]
          AND [h2].[ObjectName]=[h].[ObjectName]
          AND [h2].[StatisticsName]=[h].[StatisticsName]
    ) AS [mx]
    GROUP BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatisticsId];

    /*
    Predicate-/Parameterextraktion. Die Rohwerte bleiben in dieser internen
    Temp-Tabelle und werden weder von dieser Procedure ausgegeben noch persistiert.
    */
    IF @MitPredicateHistogramMap=1 AND EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_HistogramSteps])
    BEGIN
        ;WITH [StatementsBase] AS
        (
            SELECT
                  [StatementXml]=[s].[n].query('.')
                , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
                , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
                , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'')
            FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
        ),
        [Statements] AS
        (
            SELECT
                  [StatementOrdinal]=CONVERT(int,ROW_NUMBER() OVER
                    (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
                , [StatementXml]
            FROM [StatementsBase]
        )
        INSERT [#InternalCollectExecutionPlanMetadata_PredicateValues]
        (
              [StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName]
            , [ColumnName],[PredicateKind],[ParameterName]
            , [CompiledValueRaw],[RuntimeValueRaw]
            , [CompiledValueNormalized],[RuntimeValueNormalized]
        )
        SELECT DISTINCT
              [st].[StatementOrdinal]
            , TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , [v].[DatabaseName],[v].[SchemaName],[v].[ObjectName],[v].[ColumnName]
            , NULLIF([c].[n].value('string((@CompareOp)[1])','nvarchar(40)'),N'')
            , NULLIF([p].[ParameterName],N'')
            , NULLIF([p].[CompiledValue],N'')
            , NULLIF([p].[RuntimeValue],N'')
            , [n].[CompiledNormalized]
            , [n].[RuntimeNormalized]
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        CROSS APPLY [r].[n].nodes('./*//*[local-name(.)="Compare"]') AS [c]([n])
        CROSS APPLY
        (
            VALUES
            (
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Database)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Schema)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Table)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Column)[1])','nvarchar(256)'),N'')
            )
        ) AS [cr]([DatabaseRaw],[SchemaRaw],[ObjectRaw],[ColumnRaw])
        CROSS APPLY
        (
            VALUES
            (
                CASE WHEN LEFT([cr].[DatabaseRaw],1)=N'[' AND RIGHT([cr].[DatabaseRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[DatabaseRaw],2,LEN([cr].[DatabaseRaw])-2),N']]',N']') ELSE [cr].[DatabaseRaw] END,
                CASE WHEN LEFT([cr].[SchemaRaw],1)=N'[' AND RIGHT([cr].[SchemaRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[SchemaRaw],2,LEN([cr].[SchemaRaw])-2),N']]',N']') ELSE [cr].[SchemaRaw] END,
                CASE WHEN LEFT([cr].[ObjectRaw],1)=N'[' AND RIGHT([cr].[ObjectRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[ObjectRaw],2,LEN([cr].[ObjectRaw])-2),N']]',N']') ELSE [cr].[ObjectRaw] END,
                CASE WHEN LEFT([cr].[ColumnRaw],1)=N'[' AND RIGHT([cr].[ColumnRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[ColumnRaw],2,LEN([cr].[ColumnRaw])-2),N']]',N']') ELSE [cr].[ColumnRaw] END
            )
        ) AS [v]([DatabaseName],[SchemaName],[ObjectName],[ColumnName])
        CROSS APPLY
        (
            VALUES
            (
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@ParameterCompiledValue or @ParameterRuntimeValue][1]/@Column)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@ParameterCompiledValue or @ParameterRuntimeValue][1]/@ParameterCompiledValue)[1])','nvarchar(4000)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@ParameterCompiledValue or @ParameterRuntimeValue][1]/@ParameterRuntimeValue)[1])','nvarchar(4000)'),N'')
            )
        ) AS [p]([ParameterName],[CompiledValue],[RuntimeValue])
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN LEFT([p].[CompiledValue],1)=N'(' AND RIGHT([p].[CompiledValue],1)=N')' THEN SUBSTRING([p].[CompiledValue],2,LEN([p].[CompiledValue])-2)
                    WHEN LEFT([p].[CompiledValue],2)=N'N''' AND RIGHT([p].[CompiledValue],1)=N'''' THEN SUBSTRING([p].[CompiledValue],3,LEN([p].[CompiledValue])-3)
                    WHEN LEFT([p].[CompiledValue],1)=N'''' AND RIGHT([p].[CompiledValue],1)=N'''' THEN SUBSTRING([p].[CompiledValue],2,LEN([p].[CompiledValue])-2)
                    ELSE [p].[CompiledValue] END,
                CASE
                    WHEN LEFT([p].[RuntimeValue],1)=N'(' AND RIGHT([p].[RuntimeValue],1)=N')' THEN SUBSTRING([p].[RuntimeValue],2,LEN([p].[RuntimeValue])-2)
                    WHEN LEFT([p].[RuntimeValue],2)=N'N''' AND RIGHT([p].[RuntimeValue],1)=N'''' THEN SUBSTRING([p].[RuntimeValue],3,LEN([p].[RuntimeValue])-3)
                    WHEN LEFT([p].[RuntimeValue],1)=N'''' AND RIGHT([p].[RuntimeValue],1)=N'''' THEN SUBSTRING([p].[RuntimeValue],2,LEN([p].[RuntimeValue])-2)
                    ELSE [p].[RuntimeValue] END
            )
        ) AS [n]([CompiledNormalized],[RuntimeNormalized])
        WHERE [v].[DatabaseName] IS NOT NULL AND [v].[SchemaName] IS NOT NULL
          AND [v].[ObjectName] IS NOT NULL AND [v].[ColumnName] IS NOT NULL
          AND ([p].[CompiledValue] IS NOT NULL OR [p].[RuntimeValue] IS NOT NULL);

        ;WITH [ValuesToMap] AS
        (
            SELECT [PredicateReferenceId],[StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName],[ColumnName],
                   [PredicateKind],CONVERT(varchar(32),'COMPILED_PARAMETER') [ValueSource],[CompiledValueNormalized] [ValueText]
            FROM [#InternalCollectExecutionPlanMetadata_PredicateValues] WHERE [CompiledValueNormalized] IS NOT NULL
            UNION ALL
            SELECT [PredicateReferenceId],[StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName],[ColumnName],
                   [PredicateKind],'RUNTIME_PARAMETER',[RuntimeValueNormalized]
            FROM [#InternalCollectExecutionPlanMetadata_PredicateValues] WHERE [RuntimeValueNormalized] IS NOT NULL
        ),
        [Candidates] AS
        (
            SELECT
                  [v].*
                , [h].[StatisticsName],[h].[StepOrdinal],[h].[RangeHighKeyRaw]
                , [NumericValue]=TRY_CONVERT(decimal(38,10),[v].[ValueText])
                , [NumericBoundary]=TRY_CONVERT(decimal(38,10),[h].[RangeHighKeyRaw])
                , [DateValue]=TRY_CONVERT(datetime2(7),[v].[ValueText])
                , [DateBoundary]=TRY_CONVERT(datetime2(7),[h].[RangeHighKeyRaw])
                , [ExactMatch]=CONVERT(bit,CASE WHEN [v].[ValueText]=[h].[RangeHighKeyRaw] THEN 1 ELSE 0 END)
            FROM [ValuesToMap] AS [v]
            JOIN [#CreateExecutionEvidenceJson_HistogramSteps] AS [h]
              ON [h].[DatabaseName]=[v].[DatabaseName]
             AND [h].[SchemaName]=[v].[SchemaName]
             AND [h].[ObjectName]=[v].[ObjectName]
             AND [h].[LeadingColumnName]=[v].[ColumnName]
        ),
        [Ranked] AS
        (
            SELECT [c].*,
                   [CandidateRank]=ROW_NUMBER() OVER
                   (
                       PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]
                       ORDER BY CASE WHEN [ExactMatch]=1 THEN 0
                                     WHEN [NumericValue] IS NOT NULL AND [NumericBoundary]>=[NumericValue] THEN 1
                                     WHEN [DateValue] IS NOT NULL AND [DateBoundary]>=[DateValue] THEN 1
                                     ELSE 2 END,
                                [StepOrdinal]
                   ),
                   [MinimumNumericBoundary]=MIN([NumericBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]),
                   [MaximumNumericBoundary]=MAX([NumericBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]),
                   [MinimumDateBoundary]=MIN([DateBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]),
                   [MaximumDateBoundary]=MAX([DateBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName])
            FROM [Candidates] AS [c]
        )
        INSERT [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
        (
              [PredicateReferenceId],[StatementOrdinal],[NodeId]
            , [DatabaseName],[SchemaName],[ObjectName],[ColumnName]
            , [StatisticsName],[PredicateKind],[ValueSource]
            , [MappingStatus],[MappingConfidence],[MatchedStepOrdinal]
            , [MatchesRangeHighKey],[IsBelowHistogram],[IsAboveHistogram]
            , [SensitiveValueStatus]
        )
        SELECT
              [PredicateReferenceId],[StatementOrdinal],[NodeId]
            , [DatabaseName],[SchemaName],[ObjectName],[ColumnName]
            , [StatisticsName],[PredicateKind],[ValueSource]
            , CASE
                WHEN [ExactMatch]=1 THEN 'EXACT_RANGE_HIGH_KEY'
                WHEN [NumericValue] IS NOT NULL AND [NumericValue]<[MinimumNumericBoundary] THEN 'BELOW_HISTOGRAM_MINIMUM'
                WHEN [NumericValue] IS NOT NULL AND [NumericValue]>[MaximumNumericBoundary] THEN 'ABOVE_HISTOGRAM_MAXIMUM'
                WHEN [DateValue] IS NOT NULL AND [DateValue]<[MinimumDateBoundary] THEN 'BELOW_HISTOGRAM_MINIMUM'
                WHEN [DateValue] IS NOT NULL AND [DateValue]>[MaximumDateBoundary] THEN 'ABOVE_HISTOGRAM_MAXIMUM'
                WHEN ([NumericValue] IS NOT NULL AND [NumericBoundary]>=[NumericValue])
                  OR ([DateValue] IS NOT NULL AND [DateBoundary]>=[DateValue]) THEN 'WITHIN_HISTOGRAM_RANGE'
                ELSE 'NOT_MAPPABLE' END
            , CASE WHEN [ExactMatch]=1 THEN 'HIGH'
                   WHEN [NumericValue] IS NOT NULL OR [DateValue] IS NOT NULL THEN 'MEDIUM'
                   ELSE 'LOW' END
            , CASE WHEN [ExactMatch]=1
                     OR ([NumericValue] IS NOT NULL AND [NumericBoundary]>=[NumericValue])
                     OR ([DateValue] IS NOT NULL AND [DateBoundary]>=[DateValue])
                   THEN [StepOrdinal] END
            , [ExactMatch]
            , CONVERT(bit,CASE WHEN ([NumericValue] IS NOT NULL AND [NumericValue]<[MinimumNumericBoundary])
                                  OR ([DateValue] IS NOT NULL AND [DateValue]<[MinimumDateBoundary]) THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN ([NumericValue] IS NOT NULL AND [NumericValue]>[MaximumNumericBoundary])
                                  OR ([DateValue] IS NOT NULL AND [DateValue]>[MaximumDateBoundary]) THEN 1 ELSE 0 END)
            , 'OMITTED_DERIVED_ONLY'
        FROM [Ranked]
        WHERE [CandidateRank]=1;
    END;

    INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
    ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[CollectionStatus],NULL,NULL
    FROM [#CreateExecutionEvidenceJson_StatisticsCurrent]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [#CreateExecutionEvidenceJson_CollectionStatus] AS [x]
        WHERE [x].[DatabaseName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[DatabaseName]
          AND [x].[SchemaName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[SchemaName]
          AND [x].[ObjectName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[ObjectName]
          AND [x].[StatisticsName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[StatisticsName]
    );

    IF @IsPartialOut=1 AND @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCodeOut=CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END
            , @IsPartialOut=1
            , @ErrorNumberOut=ERROR_NUMBER()
            , @ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;
END;
GO
-- END SOURCE: Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql

-- BEGIN SOURCE: Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql
/*
===============================================================================
Objekt       : monitor.InternalAnalyzeExecutionPlan
Version      : 1.2.0
Stand        : 2026-07-23
Typ          : Interne Stored Procedure
Zweck        : Zerlegt genau ein Showplan-XML einmalig in statementgenaue,
               relationale Plan-, Operator-, Runtime-, Statistik-, Parameter-,
               Warnungs-, Optimizer-, Feedback- und Findingtabellen des Aufrufers.
Voraussetzung: Der Aufrufer legt die lokalen #ExecutionPlanAnalysis_*-Temp-Tabellen entsprechend
               dem Resultsetinventar an. Keine Benutzertabellenzugriffe.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalAnalyzeExecutionPlan]
      @AnalysisObjectId          int
    , @PlanXml                   xml
    , @PlanSource                varchar(24)
    , @RuntimeCounterScope       varchar(32)
    , @WorkloadProfile           varchar(32) = 'BALANCED'
    , @MinSeverity               varchar(16) = 'INFO'
    , @EvidenceJson              nvarchar(max) = NULL
    , @MitThreadRuntime          bit = 0
    , @EvidenzDatenschutzModus   varchar(24) = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus varchar(16) = 'RAW'
    , @SourceObservedAtUtc         datetime2(3) = NULL
    , @ParameterEvidenceSessionId                  smallint = NULL
    , @ParameterEvidenceRequestId                  int = NULL
    , @PlanHandle                 varbinary(64) = NULL
    , @QueryStoreDatabaseName     sysname = NULL
    , @QueryStorePlanId           bigint = NULL
    , @StatusCodeOut             varchar(40) = NULL OUTPUT
    , @IsPartialOut              bit = NULL OUTPUT
    , @ErrorNumberOut            int = NULL OUTPUT
    , @ErrorMessageOut           nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT
          @WorkloadProfile=UPPER(LTRIM(RTRIM(COALESCE(@WorkloadProfile,'BALANCED'))))
        , @MinSeverity=UPPER(LTRIM(RTRIM(COALESCE(@MinSeverity,'INFO'))))
        , @EvidenzDatenschutzModus=UPPER(LTRIM(RTRIM(COALESCE(@EvidenzDatenschutzModus,'DERIVED_ONLY'))))
        , @IdentifierDatenschutzModus=UPPER(LTRIM(RTRIM(COALESCE(@IdentifierDatenschutzModus,'RAW'))))
        , @SourceObservedAtUtc=COALESCE(@SourceObservedAtUtc,SYSUTCDATETIME())
        , @StatusCodeOut='AVAILABLE'
        , @IsPartialOut=0
        , @ErrorNumberOut=NULL
        , @ErrorMessageOut=NULL;

    IF @AnalysisObjectId IS NULL OR @AnalysisObjectId<1 OR @PlanXml IS NULL
       OR @PlanSource NOT IN ('IMPORTED','COMPILE','LAST_ACTUAL','CURRENT_ACTUAL','QUERY_STORE')
       OR @RuntimeCounterScope NOT IN ('NONE','LAST_COMPLETED_EXECUTION','CURRENT_PARTIAL_EXECUTION','IMPORTED_ACTUAL','QUERY_STORE_AGGREGATE','UNKNOWN')
       OR @MinSeverity NOT IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL')
       OR @MitThreadRuntime NOT IN (0,1)
       OR @EvidenzDatenschutzModus NOT IN ('DERIVED_ONLY','TOKENIZED','RAW','STRUCTURE_ONLY')
       OR @IdentifierDatenschutzModus NOT IN ('RAW','TOKENIZED','OMIT')
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültige Plan-, Quell-, Scope-, Severity- oder Datenschutzparameter.';
        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM [monitor].[PlanAnalysisProfile]
        WHERE [ProfileCode]=@WorkloadProfile AND [IsEnabled]=1
    )
        SET @WorkloadProfile='BALANCED';

    BEGIN TRY
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_Capabilities];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_PlanDocuments];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_Statements];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_Operators];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_OperatorRuntime];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_AccessPaths];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_StatisticsUsage];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_Parameters];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_ParameterEvidence];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_SourceContext];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_PlanWarnings];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_OptimizerContext];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_RuntimeFeedback];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_QueryStoreContext];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_FeedbackAndVariants];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_MemoryAndSpills];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_ExecutionEvidence];
        SELECT TOP (0) * FROM [#ExecutionPlanAnalysis_Findings];
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut='INTERNAL_ERROR',@IsPartialOut=1,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=N'Die erwarteten lokalen #ExecutionPlanAnalysis_*-Temp-Tabellen fehlen oder besitzen ein unpassendes Schema.';
        RETURN;
    END CATCH;

    CREATE TABLE [#InternalAnalyzeExecutionPlan_StatementXml]
    (
          [StatementOrdinal] int NOT NULL PRIMARY KEY
        , [StatementId] int NULL
        , [StatementCompId] int NULL
        , [StatementXml] xml NOT NULL
    );
    CREATE TABLE [#InternalAnalyzeExecutionPlan_Edges]
    (
          [StatementOrdinal] int NOT NULL
        , [ParentNodeId] int NOT NULL
        , [ChildNodeId] int NOT NULL
        , [ChildOrdinal] int NOT NULL
        , PRIMARY KEY ([StatementOrdinal],[ParentNodeId],[ChildNodeId])
    );

    BEGIN TRY
        ;WITH [StatementBase] AS
        (
            SELECT
                  [StatementXml]=[s].[n].query('.')
                , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
                , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
                , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'')
            FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
        )
        INSERT [#InternalAnalyzeExecutionPlan_StatementXml]
        ([StatementOrdinal],[StatementId],[StatementCompId],[StatementXml])
        SELECT
              CONVERT(int,ROW_NUMBER() OVER
                (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
            , [StatementId],[StatementCompId],[StatementXml]
        FROM [StatementBase];

        IF NOT EXISTS(SELECT 1 FROM [#InternalAnalyzeExecutionPlan_StatementXml])
        BEGIN
            INSERT [#ExecutionPlanAnalysis_Capabilities]
            VALUES(@AnalysisObjectId,'STATEMENTS',0,'NO_STMT_SIMPLE','PLAN_XML',N'Das Plan-XML enthält kein unterstütztes StmtSimple-Element.');
            SELECT @StatusCodeOut='UNAVAILABLE_OBJECT',@IsPartialOut=1,
                   @ErrorMessageOut=N'Das Plan-XML enthält keine analysierbaren StmtSimple-Elemente.';
            RETURN;
        END;

        INSERT [#ExecutionPlanAnalysis_Statements]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[StatementCompId]
            , [StatementType],[StatementText],[StatementQueryHash],[StatementQueryPlanHash]
            , [StatementSubTreeCost],[StatementEstimatedRows],[OptimizationLevel]
            , [EarlyAbortReason],[CardinalityEstimationModelVersion]
            , [CompileTimeMs],[CompileCpuMs],[CompileMemoryKb]
            , [RetrievedFromCache],[NonParallelPlanReason]
        )
        SELECT
              @AnalysisObjectId,[x].[StatementOrdinal],[x].[StatementId],[x].[StatementCompId]
            , NULLIF([x].[StatementXml].value('string((/*/@StatementType)[1])','nvarchar(128)'),N'')
            , NULLIF([x].[StatementXml].value('string((/*/@StatementText)[1])','nvarchar(max)'),N'')
            , NULLIF([x].[StatementXml].value('string((/*/@QueryHash)[1])','nvarchar(130)'),N'')
            , NULLIF([x].[StatementXml].value('string((/*/@QueryPlanHash)[1])','nvarchar(130)'),N'')
            , TRY_CONVERT(decimal(38,8),NULLIF([x].[StatementXml].value('string((/*/@StatementSubTreeCost)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([x].[StatementXml].value('string((/*/@StatementEstRows)[1])','nvarchar(100)'),N''))
            , NULLIF([x].[StatementXml].value('string((/*/@StatementOptmLevel)[1])','nvarchar(128)'),N'')
            , NULLIF([x].[StatementXml].value('string((/*/@StatementOptmEarlyAbortReason)[1])','nvarchar(256)'),N'')
            , TRY_CONVERT(int,NULLIF([x].[StatementXml].value('string((.//*[local-name(.)="QueryPlan"]/@CardinalityEstimationModelVersion)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([x].[StatementXml].value('string((.//*[local-name(.)="QueryPlan"]/@CompileTime)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([x].[StatementXml].value('string((.//*[local-name(.)="QueryPlan"]/@CompileCPU)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([x].[StatementXml].value('string((.//*[local-name(.)="QueryPlan"]/@CompileMemory)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bit,NULLIF([x].[StatementXml].value('string((/*/@RetrievedFromCache)[1])','nvarchar(20)'),N''))
            , NULLIF([x].[StatementXml].value('string((.//*[local-name(.)="QueryPlan"]/@NonParallelPlanReason)[1])','nvarchar(256)'),N'')
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [x];

        INSERT [#ExecutionPlanAnalysis_Operators]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [ParentNodeId],[ChildOrdinal],[Depth],[OperatorPath]
            , [PhysicalOp],[LogicalOp],[EstimateRows],[EstimatedRowsRead]
            , [EstimatedExecutions],[EstimateRebinds],[EstimateRewinds]
            , [EstimatedCpu],[EstimatedIo],[AverageRowSize],[EstimatedTotalSubtreeCost]
            , [Parallel],[EstimatedExecutionMode],[ActualExecutionMode]
            , [Ordered],[ScanDirection]
            , [ObjectDatabaseName],[ObjectSchemaName],[ObjectName],[IndexName]
        )
        SELECT
              @AnalysisObjectId,[st].[StatementOrdinal],[st].[StatementId]
            , TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , NULL,NULL,NULL,NULL
            , NULLIF([r].[n].value('string((@PhysicalOp)[1])','nvarchar(128)'),N'')
            , NULLIF([r].[n].value('string((@LogicalOp)[1])','nvarchar(128)'),N'')
            , TRY_CONVERT(decimal(38,4),NULLIF([r].[n].value('string((@EstimateRows)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([r].[n].value('string((@EstimatedRowsRead)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([r].[n].value('string((@EstimateExecutions)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([r].[n].value('string((@EstimateRebinds)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([r].[n].value('string((@EstimateRewinds)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,8),NULLIF([r].[n].value('string((@EstimateCPU)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,8),NULLIF([r].[n].value('string((@EstimateIO)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([r].[n].value('string((@AvgRowSize)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,8),NULLIF([r].[n].value('string((@EstimatedTotalSubtreeCost)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bit,NULLIF([r].[n].value('string((@Parallel)[1])','nvarchar(20)'),N''))
            , NULLIF([r].[n].value('string((@EstimatedExecutionMode)[1])','nvarchar(60)'),N'')
            , NULLIF([r].[n].value('string((@ActualExecutionMode)[1])','nvarchar(60)'),N'')
            , TRY_CONVERT(bit,NULLIF([r].[n].value('string((./*/*/@Ordered)[1])','nvarchar(20)'),N''))
            , NULLIF([r].[n].value('string((./*/*/@ScanDirection)[1])','nvarchar(60)'),N'')
            , NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Database)[1])','nvarchar(256)'),N'')
            , NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Schema)[1])','nvarchar(256)'),N'')
            , NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Table)[1])','nvarchar(256)'),N'')
            , NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Index)[1])','nvarchar(256)'),N'')
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n]);

        INSERT [#InternalAnalyzeExecutionPlan_Edges]
        ([StatementOrdinal],[ParentNodeId],[ChildNodeId],[ChildOrdinal])
        SELECT
              [st].[StatementOrdinal]
            , TRY_CONVERT(int,NULLIF([p].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , TRY_CONVERT(int,NULLIF([c].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , CONVERT(int,ROW_NUMBER() OVER
                (PARTITION BY [st].[StatementOrdinal],TRY_CONVERT(int,NULLIF([p].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
                 ORDER BY TRY_CONVERT(int,NULLIF([c].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))))
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [p]([n])
        CROSS APPLY [p].[n].nodes('./*/*[local-name(.)="RelOp"]') AS [c]([n])
        WHERE NULLIF([p].[n].value('string((@NodeId)[1])','nvarchar(50)'),N'') IS NOT NULL
          AND NULLIF([c].[n].value('string((@NodeId)[1])','nvarchar(50)'),N'') IS NOT NULL;

        UPDATE [o]
        SET [o].[ParentNodeId]=[e].[ParentNodeId],
            [o].[ChildOrdinal]=[e].[ChildOrdinal]
        FROM [#ExecutionPlanAnalysis_Operators] AS [o]
        JOIN [#InternalAnalyzeExecutionPlan_Edges] AS [e]
          ON [e].[StatementOrdinal]=[o].[StatementOrdinal]
         AND [e].[ChildNodeId]=[o].[NodeId]
        WHERE [o].[AnalysisObjectId]=@AnalysisObjectId;

        UPDATE [#ExecutionPlanAnalysis_Operators]
        SET [Depth]=0,
            [OperatorPath]=CONCAT(N'/',CONVERT(nvarchar(20),[NodeId]))
        WHERE [AnalysisObjectId]=@AnalysisObjectId
          AND [ParentNodeId] IS NULL;

        DECLARE @Depth int=0,@Changed int=1;
        WHILE @Changed>0 AND @Depth<256
        BEGIN
            SET @Depth+=1;
            UPDATE [c]
            SET [c].[Depth]=@Depth,
                [c].[OperatorPath]=CONCAT([p].[OperatorPath],N'/',CONVERT(nvarchar(20),[c].[NodeId]))
            FROM [#ExecutionPlanAnalysis_Operators] AS [c]
            JOIN [#ExecutionPlanAnalysis_Operators] AS [p]
              ON [p].[AnalysisObjectId]=[c].[AnalysisObjectId]
             AND [p].[StatementOrdinal]=[c].[StatementOrdinal]
             AND [p].[NodeId]=[c].[ParentNodeId]
            WHERE [c].[AnalysisObjectId]=@AnalysisObjectId
              AND [c].[Depth] IS NULL
              AND [p].[Depth]=@Depth-1;
            SET @Changed=@@ROWCOUNT;
        END;

        IF EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_Operators]
            WHERE [AnalysisObjectId]=@AnalysisObjectId AND [Depth] IS NULL
        )
        BEGIN
            SET @IsPartialOut=1;
            INSERT [#ExecutionPlanAnalysis_Capabilities]
            VALUES(@AnalysisObjectId,'OPERATOR_TREE',0,'UNRESOLVED_PARENT_PATH','PLAN_XML',N'Mindestens ein Operator konnte nicht in einen eindeutigen Parentpfad eingeordnet werden.');
        END
        ELSE
            INSERT [#ExecutionPlanAnalysis_Capabilities]
            VALUES(@AnalysisObjectId,'OPERATOR_TREE',1,'AVAILABLE','PLAN_XML',N'Parent, Child-Ordinal, Tiefe und Operatorpfad wurden relational ermittelt.');

        INSERT [#ExecutionPlanAnalysis_OperatorThreadRuntime]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [ThreadId],[BrickId],[ActualRows],[ActualRowsRead],[ActualExecutions]
            , [ActualRebinds],[ActualRewinds],[ActualEndOfScans],[ActualScans]
            , [ActualLogicalReads],[ActualPhysicalReads],[ActualReadAheads]
            , [ActualCpuMs],[ActualElapsedMs]
            , [ActualLobLogicalReads],[ActualLobPhysicalReads],[IsRowsReadPaired]
        )
        SELECT
              @AnalysisObjectId,[st].[StatementOrdinal],[st].[StatementId]
            , TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , TRY_CONVERT(int,NULLIF([t].[n].value('string((@Thread)[1])','nvarchar(50)'),N''))
            , TRY_CONVERT(int,NULLIF([t].[n].value('string((@BrickId)[1])','nvarchar(50)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([t].[n].value('string((@ActualRows)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(decimal(38,4),NULLIF([t].[n].value('string((@ActualRowsRead)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualExecutions)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualRebinds)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualRewinds)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualEndOfScans)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualScans)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualLogicalReads)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualPhysicalReads)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualReadAheads)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualCPUms)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualElapsedms)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualLobLogicalReads)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([t].[n].value('string((@ActualLobPhysicalReads)[1])','nvarchar(100)'),N''))
            , CONVERT(bit,CASE WHEN NULLIF([t].[n].value('string((@ActualRowsRead)[1])','nvarchar(100)'),N'') IS NOT NULL
                               THEN 1 ELSE 0 END)
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        CROSS APPLY [r].[n].nodes('./*[local-name(.)="RunTimeInformation"]/*[local-name(.)="RunTimeCountersPerThread"]') AS [t]([n]);

        INSERT [#ExecutionPlanAnalysis_OperatorRuntime]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [RuntimeCounterCount],[RowsReadCounterCount],[RowsReadCounterCoveragePercent]
            , [ActualRows],[ActualRowsRead],[PairedActualRows],[PairedActualRowsRead]
            , [ActualExecutions],[ActualRebinds],[ActualRewinds]
            , [ActualLogicalReads],[ActualPhysicalReads],[ActualReadAheads]
            , [ActualCpuMs],[ActualElapsedMs]
            , [EstimatedRowsTotal],[ActualToEstimatedRatio],[CardinalityLog10Error]
            , [RowsReadNotReturned],[RowsReadNotReturnedPercent],[RuntimeMetricStatus]
        )
        SELECT
              [o].[AnalysisObjectId],[o].[StatementOrdinal],[o].[StatementId],[o].[NodeId]
            , COUNT([t].[NodeId])
            , SUM(CONVERT(int,COALESCE([t].[IsRowsReadPaired],0)))
            , CONVERT(decimal(9,4),100.0*SUM(CONVERT(int,COALESCE([t].[IsRowsReadPaired],0)))/NULLIF(COUNT([t].[NodeId]),0))
            , SUM([t].[ActualRows])
            , SUM([t].[ActualRowsRead])
            , SUM(CASE WHEN [t].[IsRowsReadPaired]=1 THEN [t].[ActualRows] END)
            , SUM(CASE WHEN [t].[IsRowsReadPaired]=1 THEN [t].[ActualRowsRead] END)
            , SUM([t].[ActualExecutions]),SUM([t].[ActualRebinds]),SUM([t].[ActualRewinds])
            , SUM([t].[ActualLogicalReads]),SUM([t].[ActualPhysicalReads]),SUM([t].[ActualReadAheads])
            , SUM([t].[ActualCpuMs]),MAX([t].[ActualElapsedMs])
            , TRY_CONVERT(decimal(38,4),CONVERT(float,[o].[EstimateRows])*
                CONVERT(float,CASE WHEN [o].[EstimateRebinds] IS NOT NULL OR [o].[EstimateRewinds] IS NOT NULL
                                   THEN 1+COALESCE([o].[EstimateRebinds],0)+COALESCE([o].[EstimateRewinds],0)
                                   ELSE COALESCE(NULLIF([o].[EstimatedExecutions],0),1) END))
            , NULL,NULL,NULL,NULL
            , CASE WHEN COUNT([t].[NodeId])=0 THEN 'NO_RUNTIME_INFORMATION'
                   WHEN SUM(CONVERT(int,COALESCE([t].[IsRowsReadPaired],0)))=0 THEN 'ACTUAL_ROWS_READ_NOT_AVAILABLE'
                   WHEN SUM(CONVERT(int,COALESCE([t].[IsRowsReadPaired],0)))<COUNT([t].[NodeId]) THEN 'PARTIAL_COUNTER_COVERAGE'
                   ELSE 'AVAILABLE' END
        FROM [#ExecutionPlanAnalysis_Operators] AS [o]
        LEFT JOIN [#ExecutionPlanAnalysis_OperatorThreadRuntime] AS [t]
          ON [t].[AnalysisObjectId]=[o].[AnalysisObjectId]
         AND [t].[StatementOrdinal]=[o].[StatementOrdinal]
         AND [t].[NodeId]=[o].[NodeId]
        WHERE [o].[AnalysisObjectId]=@AnalysisObjectId
        GROUP BY
              [o].[AnalysisObjectId],[o].[StatementOrdinal],[o].[StatementId],[o].[NodeId]
            , [o].[EstimateRows],[o].[EstimateRebinds],[o].[EstimateRewinds],[o].[EstimatedExecutions];

        UPDATE [r]
        SET
              [ActualToEstimatedRatio]=CASE
                  WHEN [r].[ActualRows] IS NOT NULL AND [r].[EstimatedRowsTotal]>0
                  THEN TRY_CONVERT(decimal(38,8),CONVERT(decimal(38,12),[r].[ActualRows])
                       /NULLIF(CONVERT(decimal(38,12),[r].[EstimatedRowsTotal]),CONVERT(decimal(38,12),0))) END
            , [CardinalityLog10Error]=CASE
                  WHEN [r].[ActualRows] IS NOT NULL AND [r].[EstimatedRowsTotal] IS NOT NULL
                  THEN TRY_CONVERT(decimal(19,6),ABS(LOG10
                       ((CONVERT(float,[r].[ActualRows])+1.0)/(CONVERT(float,[r].[EstimatedRowsTotal])+1.0)))) END
            , [RowsReadNotReturned]=CASE
                  WHEN [r].[PairedActualRowsRead] IS NOT NULL AND [r].[PairedActualRows] IS NOT NULL
                   AND [r].[PairedActualRowsRead]>=[r].[PairedActualRows]
                  THEN TRY_CONVERT(decimal(38,4),CONVERT(decimal(38,4),[r].[PairedActualRowsRead])-CONVERT(decimal(38,4),[r].[PairedActualRows])) END
            , [RowsReadNotReturnedPercent]=CASE
                  WHEN [r].[PairedActualRowsRead] IS NULL OR [r].[PairedActualRows] IS NULL THEN NULL
                  WHEN [r].[PairedActualRowsRead]<=0 THEN NULL
                  WHEN [r].[PairedActualRows]<0 OR [r].[PairedActualRows]>[r].[PairedActualRowsRead] THEN NULL
                  ELSE CONVERT(decimal(19,6),CONVERT(decimal(38,12),100)*
                       (CONVERT(decimal(38,12),[r].[PairedActualRowsRead])-CONVERT(decimal(38,12),[r].[PairedActualRows]))
                       /CONVERT(decimal(38,12),[r].[PairedActualRowsRead])) END
            , [RuntimeMetricStatus]=CASE
                  WHEN [r].[RuntimeCounterCount]=0 THEN 'NO_RUNTIME_INFORMATION'
                  WHEN [r].[RowsReadCounterCount]=0 THEN 'ACTUAL_ROWS_READ_NOT_AVAILABLE'
                  WHEN [r].[PairedActualRowsRead]<[r].[PairedActualRows] THEN 'INCONSISTENT_COUNTERS'
                  WHEN [r].[RowsReadCounterCount]<[r].[RuntimeCounterCount] THEN 'PARTIAL_COUNTER_COVERAGE'
                  WHEN [r].[PairedActualRowsRead]=0 THEN 'ZERO_ROWS_READ'
                  ELSE 'AVAILABLE' END
        FROM [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
        WHERE [r].[AnalysisObjectId]=@AnalysisObjectId;

        INSERT [#ExecutionPlanAnalysis_AccessPaths]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[DatabaseName],[SchemaName],[ObjectName]
            , [IndexName],[StorageType],[IsLookup],[Ordered],[ScanDirection]
            , [EstimateRows],[EstimatedRowsRead],[ActualRows],[ActualRowsRead]
            , [ActualExecutions],[RowsReadNotReturned],[RowsReadNotReturnedPercent]
        )
        SELECT
              [o].[AnalysisObjectId],[o].[StatementOrdinal],[o].[StatementId],[o].[NodeId]
            , [o].[PhysicalOp],[o].[LogicalOp],[o].[ObjectDatabaseName]
            , [o].[ObjectSchemaName],[o].[ObjectName],[o].[IndexName],NULL
            , CONVERT(bit,CASE WHEN [o].[PhysicalOp] IN (N'Key Lookup',N'RID Lookup') THEN 1 ELSE 0 END)
            , [o].[Ordered],[o].[ScanDirection],[o].[EstimateRows],[o].[EstimatedRowsRead]
            , [r].[ActualRows],[r].[ActualRowsRead],[r].[ActualExecutions]
            , [r].[RowsReadNotReturned],[r].[RowsReadNotReturnedPercent]
        FROM [#ExecutionPlanAnalysis_Operators] AS [o]
        LEFT JOIN [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
          ON [r].[AnalysisObjectId]=[o].[AnalysisObjectId]
         AND [r].[StatementOrdinal]=[o].[StatementOrdinal]
         AND [r].[NodeId]=[o].[NodeId]
        WHERE [o].[AnalysisObjectId]=@AnalysisObjectId
          AND
          (
              [o].[PhysicalOp] LIKE N'%Scan%'
              OR [o].[PhysicalOp] LIKE N'%Seek%'
              OR [o].[PhysicalOp] IN (N'Key Lookup',N'RID Lookup')
          );

        INSERT [#ExecutionPlanAnalysis_StatisticsUsage]
        (
              [AnalysisObjectId],[StatisticsUsageOrdinal],[StatementOrdinal]
            , [StatementId],[StatementCompId],[DatabaseName],[SchemaName]
            , [ObjectName],[StatisticsName],[LastUpdateAtCompile]
            , [ModificationCountAtCompile],[SamplingPercentAtCompile]
            , [CurrentLastUpdated],[CurrentRows],[CurrentRowsSampled]
            , [CurrentModificationCounter],[CurrentSamplePercent]
            , [StatisticsChangedSinceCompile],[MetadataMatchStatus]
        )
        SELECT
              @AnalysisObjectId,[StatisticsUsageOrdinal],[StatementOrdinal]
            , [StatementId],[StatementCompId],[DatabaseName],[SchemaName]
            , [ObjectName],[StatisticsName],[LastUpdateAtCompile]
            , [ModificationCountAtCompile],[SamplingPercentAtCompile]
            , NULL,NULL,NULL,NULL,NULL,NULL,'PLAN_ONLY'
        FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml,NULL);

        DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);

        /*
          DIAG-003: Das Showplan-Parameterelement wird genau einmal zerlegt.
          Der kanonische Vertrag bewahrt Attributpräsenz, SQL-NULL-Semantik,
          Quellzeit und Ausführungsscope; das Legacy-Resultset wird anschließend
          ausschließlich aus derselben Materialisierung projiziert.
        */
        INSERT [#ExecutionPlanAnalysis_ParameterEvidence]
        (
              [CandidateId],[SessionId],[RequestId],[StatementOrdinal],[StatementId]
            , [StatementQueryHash],[StatementQueryPlanHash],[PlanHandle]
            , [QueryStoreDatabaseName],[QueryStorePlanId],[PlanDocumentHash]
            , [EvidenceKind],[ParameterName],[ParameterDataType]
            , [CompiledValuePresent],[RuntimeValuePresent]
            , [CompiledValueIsSqlNull],[RuntimeValueIsSqlNull]
            , [CompiledValue],[RuntimeValue]
            , [CompiledValueToken],[RuntimeValueToken]
            , [CompiledValueLength],[RuntimeValueLength]
            , [CompiledValueStatus],[RuntimeValueStatus],[ValueStatus]
            , [ValueHandlingStatus],[ValueSource]
            , [SourceObservedAtUtc],[ValueCapturedAtUtc]
            , [IsCurrentExecution],[IsLastKnownExecution],[IsComplete],[EvidenceLimit]
        )
        SELECT
              @AnalysisObjectId,@ParameterEvidenceSessionId,@ParameterEvidenceRequestId,[st].[StatementOrdinal],[st].[StatementId]
            , [q].[StatementQueryHash],[q].[StatementQueryPlanHash],@PlanHandle
            , @QueryStoreDatabaseName,@QueryStorePlanId,NULL
            , 'PARAMETER'
            , NULLIF([p].[n].value('string((@Column)[1])','nvarchar(256)'),N'')
            , NULLIF([p].[n].value('string((@ParameterDataType)[1])','nvarchar(256)'),N'')
            , [v].[CompiledValuePresent],[v].[RuntimeValuePresent]
            , CONVERT(bit,CASE WHEN [v].[CompiledValuePresent]=1
                                    AND UPPER(LTRIM(RTRIM(COALESCE([v].[CompiledValueText],N'')))) IN (N'NULL',N'(NULL)')
                               THEN 1 WHEN [v].[CompiledValuePresent]=1 THEN 0 END)
            , CONVERT(bit,CASE WHEN [v].[RuntimeValuePresent]=1
                                    AND UPPER(LTRIM(RTRIM(COALESCE([v].[RuntimeValueText],N'')))) IN (N'NULL',N'(NULL)')
                               THEN 1 WHEN [v].[RuntimeValuePresent]=1 THEN 0 END)
            , CASE WHEN @EvidenzDatenschutzModus='RAW' THEN [v].[CompiledValueText] END
            , CASE WHEN @EvidenzDatenschutzModus='RAW' THEN [v].[RuntimeValueText] END
            , CASE WHEN @EvidenzDatenschutzModus='TOKENIZED'
                         AND [v].[CompiledValuePresent]=1
                         AND UPPER(LTRIM(RTRIM(COALESCE([v].[CompiledValueText],N'')))) NOT IN (N'NULL',N'(NULL)')
                   THEN CONVERT(nvarchar(66),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([v].[CompiledValueText],N''))),1) END
            , CASE WHEN @EvidenzDatenschutzModus='TOKENIZED'
                         AND [v].[RuntimeValuePresent]=1
                         AND UPPER(LTRIM(RTRIM(COALESCE([v].[RuntimeValueText],N'')))) NOT IN (N'NULL',N'(NULL)')
                   THEN CONVERT(nvarchar(66),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([v].[RuntimeValueText],N''))),1) END
            , CASE WHEN [v].[CompiledValuePresent]=1 THEN LEN([v].[CompiledValueText]) END
            , CASE WHEN [v].[RuntimeValuePresent]=1 THEN LEN([v].[RuntimeValueText]) END
            , CASE WHEN [v].[CompiledValuePresent]=0 THEN 'NOT_COLLECTED'
                   WHEN UPPER(LTRIM(RTRIM(COALESCE([v].[CompiledValueText],N'')))) IN (N'NULL',N'(NULL)') THEN 'SQL_NULL'
                   ELSE 'AVAILABLE' END
            , CASE WHEN [v].[RuntimeValuePresent]=0 THEN 'NOT_COLLECTED'
                   WHEN UPPER(LTRIM(RTRIM(COALESCE([v].[RuntimeValueText],N'')))) IN (N'NULL',N'(NULL)') THEN 'SQL_NULL'
                   ELSE 'AVAILABLE' END
            , CASE WHEN @RuntimeCounterScope IN ('CURRENT_PARTIAL_EXECUTION','LAST_COMPLETED_EXECUTION','IMPORTED_ACTUAL')
                   THEN CASE WHEN [v].[RuntimeValuePresent]=0 THEN 'NOT_COLLECTED'
                             WHEN UPPER(LTRIM(RTRIM(COALESCE([v].[RuntimeValueText],N'')))) IN (N'NULL',N'(NULL)') THEN 'SQL_NULL'
                             ELSE 'AVAILABLE' END
                   ELSE CASE WHEN [v].[CompiledValuePresent]=0 THEN 'NOT_COLLECTED'
                             WHEN UPPER(LTRIM(RTRIM(COALESCE([v].[CompiledValueText],N'')))) IN (N'NULL',N'(NULL)') THEN 'SQL_NULL'
                             ELSE 'AVAILABLE' END END
            , CASE @EvidenzDatenschutzModus WHEN 'RAW' THEN 'AVAILABLE_RAW'
                   WHEN 'TOKENIZED' THEN 'TOKENIZED_CAPTURE_LOCAL'
                   WHEN 'STRUCTURE_ONLY' THEN 'OMITTED_STRUCTURE_ONLY'
                   ELSE 'OMITTED_DERIVED_ONLY' END
            , CASE @PlanSource WHEN 'COMPILE' THEN 'COMPILE_PLAN'
                   WHEN 'CURRENT_ACTUAL' THEN 'LIVE_PLAN'
                   WHEN 'LAST_ACTUAL' THEN 'LAST_ACTUAL_PLAN'
                   WHEN 'QUERY_STORE' THEN 'QUERY_STORE_PLAN'
                   ELSE 'IMPORTED_PLAN' END
            , @SourceObservedAtUtc
            , CASE WHEN @PlanSource='CURRENT_ACTUAL' THEN @SourceObservedAtUtc END
            , CASE WHEN @PlanSource='CURRENT_ACTUAL' THEN CONVERT(bit,1)
                   WHEN @PlanSource='IMPORTED' THEN CONVERT(bit,NULL) ELSE CONVERT(bit,0) END
            , CASE WHEN @PlanSource='LAST_ACTUAL' THEN CONVERT(bit,1)
                   WHEN @PlanSource='IMPORTED' THEN CONVERT(bit,NULL) ELSE CONVERT(bit,0) END
            , CONVERT(bit,CASE
                  WHEN @RuntimeCounterScope IN ('CURRENT_PARTIAL_EXECUTION','LAST_COMPLETED_EXECUTION','IMPORTED_ACTUAL')
                      THEN [v].[RuntimeValuePresent]
                  ELSE [v].[CompiledValuePresent] END)
            , N'Showplan stellt nur die im gewählten Plan vorhandenen Parameterattribute bereit; lokale T-SQL-Variablenwerte sind nicht allgemein über eine DMV verfügbar.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        JOIN [#ExecutionPlanAnalysis_Statements] AS [q]
          ON [q].[AnalysisObjectId]=@AnalysisObjectId
         AND [q].[StatementOrdinal]=[st].[StatementOrdinal]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="ParameterList"]/*[local-name(.)="ColumnReference"]') AS [p]([n])
        CROSS APPLY
        (
            SELECT
                  [CompiledValuePresent]=CONVERT(bit,[p].[n].exist('@ParameterCompiledValue'))
                , [RuntimeValuePresent]=CONVERT(bit,[p].[n].exist('@ParameterRuntimeValue'))
                , [CompiledValueText]=CASE WHEN [p].[n].exist('@ParameterCompiledValue')=1
                      THEN [p].[n].value('string((@ParameterCompiledValue)[1])','nvarchar(4000)') END
                , [RuntimeValueText]=CASE WHEN [p].[n].exist('@ParameterRuntimeValue')=1
                      THEN [p].[n].value('string((@ParameterRuntimeValue)[1])','nvarchar(4000)') END
        ) AS [v];

        /* Dokumentierte Systemgrenze: lokale Variablen sind keine Showplan-Parameter. */
        INSERT [#ExecutionPlanAnalysis_ParameterEvidence]
        (
              [CandidateId],[SessionId],[RequestId],[StatementOrdinal],[StatementId]
            , [StatementQueryHash],[StatementQueryPlanHash],[PlanHandle]
            , [QueryStoreDatabaseName],[QueryStorePlanId],[PlanDocumentHash]
            , [EvidenceKind],[ParameterName],[ParameterDataType]
            , [CompiledValuePresent],[RuntimeValuePresent]
            , [CompiledValueIsSqlNull],[RuntimeValueIsSqlNull]
            , [CompiledValue],[RuntimeValue],[CompiledValueToken],[RuntimeValueToken]
            , [CompiledValueLength],[RuntimeValueLength]
            , [CompiledValueStatus],[RuntimeValueStatus],[ValueStatus]
            , [ValueHandlingStatus],[ValueSource]
            , [SourceObservedAtUtc],[ValueCapturedAtUtc]
            , [IsCurrentExecution],[IsLastKnownExecution],[IsComplete],[EvidenceLimit]
        )
        VALUES
        (
              @AnalysisObjectId,@ParameterEvidenceSessionId,@ParameterEvidenceRequestId,NULL,NULL,NULL,NULL,@PlanHandle
            , @QueryStoreDatabaseName,@QueryStorePlanId,NULL
            , 'SOURCE_BOUNDARY',NULL,NULL,0,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
            , 'NOT_COLLECTED','NOT_COLLECTED','LOCAL_VARIABLE_NOT_EXPOSED'
            , CASE @EvidenzDatenschutzModus WHEN 'RAW' THEN 'AVAILABLE_RAW'
                   WHEN 'TOKENIZED' THEN 'TOKENIZED_CAPTURE_LOCAL'
                   WHEN 'STRUCTURE_ONLY' THEN 'OMITTED_STRUCTURE_ONLY'
                   ELSE 'OMITTED_DERIVED_ONLY' END
            , CASE @PlanSource WHEN 'COMPILE' THEN 'COMPILE_PLAN'
                   WHEN 'CURRENT_ACTUAL' THEN 'LIVE_PLAN'
                   WHEN 'LAST_ACTUAL' THEN 'LAST_ACTUAL_PLAN'
                   WHEN 'QUERY_STORE' THEN 'QUERY_STORE_PLAN'
                   ELSE 'IMPORTED_PLAN' END
            , @SourceObservedAtUtc,NULL
            , CASE WHEN @PlanSource='CURRENT_ACTUAL' THEN CONVERT(bit,1)
                   WHEN @PlanSource='IMPORTED' THEN CONVERT(bit,NULL) ELSE CONVERT(bit,0) END
            , CASE WHEN @PlanSource='LAST_ACTUAL' THEN CONVERT(bit,1)
                   WHEN @PlanSource='IMPORTED' THEN CONVERT(bit,NULL) ELSE CONVERT(bit,0) END
            , 0
            , N'Lokale T-SQL-Variablenwerte sind über die ausgewerteten Plan- und DMV-Quellen nicht vollständig zugänglich.'
        );

        INSERT [#ExecutionPlanAnalysis_Parameters]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId]
            , [ParameterName],[ParameterDataType]
            , [CompiledValue],[RuntimeValue]
            , [CompiledValueToken],[RuntimeValueToken]
            , [CompiledValueLength],[RuntimeValueLength]
            , [ValueHandlingStatus],[ValueSource]
        )
        SELECT
              [CandidateId],[StatementOrdinal],[StatementId]
            , [ParameterName],[ParameterDataType],[CompiledValue],[RuntimeValue]
            , CONVERT(varbinary(32),[CompiledValueToken],1)
            , CONVERT(varbinary(32),[RuntimeValueToken],1)
            , [CompiledValueLength],[RuntimeValueLength],[ValueHandlingStatus]
            , CASE WHEN [RuntimeValuePresent]=1 THEN 'COMPILE_AND_RUNTIME_PLAN' ELSE 'COMPILE_PLAN' END
        FROM [#ExecutionPlanAnalysis_ParameterEvidence]
        WHERE [CandidateId]=@AnalysisObjectId
          AND [EvidenceKind]='PARAMETER';

        INSERT [#ExecutionPlanAnalysis_MemoryAndSpills]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [RecordType],[SpillKind],[SpillLevel],[SpilledDataSize]
            , [WritesToTempDb],[ReadsFromTempDb]
            , [RequestedMemoryKb],[GrantedMemoryKb],[MaxUsedMemoryKb]
            , [GrantWaitTimeMs],[MemoryGrantFeedbackState],[Detail]
        )
        SELECT
              @AnalysisObjectId,[st].[StatementOrdinal],[st].[StatementId],NULL
            , 'MEMORY_GRANT',NULL,NULL,NULL,NULL,NULL
            , TRY_CONVERT(bigint,NULLIF([m].[n].value('string((@RequestedMemory)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([m].[n].value('string((@GrantedMemory)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([m].[n].value('string((@MaxUsedMemory)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([m].[n].value('string((@GrantWaitTime)[1])','nvarchar(100)'),N''))
            , NULLIF([m].[n].value('string((@IsMemoryGrantFeedbackAdjusted)[1])','nvarchar(128)'),N'')
            , N'Statementbezogene MemoryGrantInfo aus dem Plan.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="MemoryGrantInfo"]') AS [m]([n]);

        INSERT [#ExecutionPlanAnalysis_MemoryAndSpills]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [RecordType],[SpillKind],[SpillLevel],[SpilledDataSize]
            , [WritesToTempDb],[ReadsFromTempDb]
            , [RequestedMemoryKb],[GrantedMemoryKb],[MaxUsedMemoryKb]
            , [GrantWaitTimeMs],[MemoryGrantFeedbackState],[Detail]
        )
        SELECT
              @AnalysisObjectId,[st].[StatementOrdinal],[st].[StatementId]
            , TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , 'SPILL',[sp].[n].value('local-name(.)','nvarchar(128)')
            , TRY_CONVERT(int,NULLIF([sp].[n].value('string((@SpillLevel)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([sp].[n].value('string((@SpilledDataSize)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([sp].[n].value('string((@WritesToTempDb)[1])','nvarchar(100)'),N''))
            , TRY_CONVERT(bigint,NULLIF([sp].[n].value('string((@ReadsFromTempDb)[1])','nvarchar(100)'),N''))
            , NULL,NULL,NULL,NULL,NULL
            , N'Operatorbezogene Spillinformation aus dem Actual Plan.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        CROSS APPLY [r].[n].nodes('./*[local-name(.)="Warnings"]/*[local-name(.)="SpillToTempDb" or local-name(.)="HashSpillDetails" or local-name(.)="SortSpillDetails" or local-name(.)="ExchangeSpillDetails"]') AS [sp]([n]);

        /* Optionale strukturierte zusätzliche Ausführungsevidenz. */
        IF @EvidenceJson IS NOT NULL AND ISJSON(@EvidenceJson)=1
        BEGIN
            INSERT [#ExecutionPlanAnalysis_ExecutionEvidence]
            (
                  [AnalysisObjectId],[EvidenceType],[StatementOrdinal]
                , [ScopeName],[MetricName],[MetricValue],[MetricUnit]
                , [EvidenceStatus],[SameExecutionConfidence]
            )
            SELECT
                  @AnalysisObjectId,'STATISTICS_IO',TRY_CONVERT(int,[j].[StatementOrdinal])
                , CASE @IdentifierDatenschutzModus WHEN 'RAW' THEN [j].[ObjectDisplayName]
                       WHEN 'TOKENIZED' THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([j].[ObjectDisplayName],N''))),1)
                       ELSE NULL END
                , [v].[MetricName],[v].[MetricValue],N'pages',[j].[ParseStatus]
                , COALESCE(JSON_VALUE(@EvidenceJson,N'$.capture.sameExecutionConfidence'),N'UNCONFIRMED')
            FROM OPENJSON(@EvidenceJson,N'$.statisticsIo')
            WITH
            (
                  [StatementOrdinal] int N'$.statementOrdinal'
                , [ObjectDisplayName] nvarchar(512) N'$.objectDisplayName'
                , [LogicalReads] decimal(38,4) N'$.logicalReads'
                , [PhysicalReads] decimal(38,4) N'$.physicalReads'
                , [ReadAheadReads] decimal(38,4) N'$.readAheadReads'
                , [ScanCount] decimal(38,4) N'$.scanCount'
                , [ParseStatus] varchar(40) N'$.parseStatus'
            ) AS [j]
            CROSS APPLY
            (
                VALUES
                  ('LOGICAL_READS',[j].[LogicalReads])
                , ('PHYSICAL_READS',[j].[PhysicalReads])
                , ('READ_AHEAD_READS',[j].[ReadAheadReads])
                , ('SCAN_COUNT',[j].[ScanCount])
            ) AS [v]([MetricName],[MetricValue])
            WHERE [v].[MetricValue] IS NOT NULL;

            INSERT [#ExecutionPlanAnalysis_ExecutionEvidence]
            (
                  [AnalysisObjectId],[EvidenceType],[StatementOrdinal]
                , [ScopeName],[MetricName],[MetricValue],[MetricUnit]
                , [EvidenceStatus],[SameExecutionConfidence]
            )
            SELECT
                  @AnalysisObjectId,'STATISTICS_TIME',TRY_CONVERT(int,[j].[StatementOrdinal])
                , [j].[TimeCategory],[v].[MetricName],[v].[MetricValue],N'ms',[j].[ParseStatus]
                , COALESCE(JSON_VALUE(@EvidenceJson,N'$.capture.sameExecutionConfidence'),N'UNCONFIRMED')
            FROM OPENJSON(@EvidenceJson,N'$.statisticsTime')
            WITH
            (
                  [StatementOrdinal] int N'$.statementOrdinal'
                , [TimeCategory] varchar(24) N'$.timeCategory'
                , [CpuMs] decimal(38,4) N'$.cpuMs'
                , [ElapsedMs] decimal(38,4) N'$.elapsedMs'
                , [ParseStatus] varchar(40) N'$.parseStatus'
            ) AS [j]
            CROSS APPLY (VALUES('CPU_MS',[j].[CpuMs]),('ELAPSED_MS',[j].[ElapsedMs])) AS [v]([MetricName],[MetricValue])
            WHERE [v].[MetricValue] IS NOT NULL;
        END
        ELSE IF @EvidenceJson IS NOT NULL
        BEGIN
            SET @IsPartialOut=1;
            INSERT [#ExecutionPlanAnalysis_Capabilities]
            VALUES(@AnalysisObjectId,'EXECUTION_EVIDENCE_JSON',0,'INVALID_JSON','EXTERNAL_EVIDENCE',N'Übergebene Ausführungsevidenz ist kein gültiges JSON.');
        END;

        /* Capabilitymodell ausschließlich nach tatsächlich vorhandenen Elementen. */
        INSERT [#ExecutionPlanAnalysis_Capabilities]
        SELECT @AnalysisObjectId,'ACTUAL_RUNTIME',CONVERT(bit,CASE WHEN EXISTS
            (SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RuntimeCounterCount]>0) THEN 1 ELSE 0 END),
            CASE WHEN EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RuntimeCounterCount]>0) THEN 'AVAILABLE' ELSE 'ATTRIBUTE_NOT_PRESENT' END,
            'PLAN_XML',N'Runtimecounter werden nur als verfügbar ausgewiesen, wenn entsprechende XML-Elemente vorhanden sind.';
        INSERT [#ExecutionPlanAnalysis_Capabilities]
        SELECT @AnalysisObjectId,'ACTUAL_ROWS_READ',CONVERT(bit,CASE WHEN EXISTS
            (SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RowsReadCounterCount]>0) THEN 1 ELSE 0 END),
            CASE WHEN EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RowsReadCounterCount]>0) THEN 'AVAILABLE' ELSE 'ATTRIBUTE_NOT_PRESENT' END,
            'PLAN_XML',N'ActualRowsRead wird threadweise gepaart und fehlende Attribute werden nicht als 0 interpretiert.';
        INSERT [#ExecutionPlanAnalysis_Capabilities]
        SELECT @AnalysisObjectId,'THREAD_RUNTIME',CONVERT(bit,CASE WHEN @MitThreadRuntime=1 AND EXISTS
            (SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RuntimeCounterCount]>1) THEN 1 ELSE 0 END),
            CASE WHEN @MitThreadRuntime=0 THEN 'NOT_REQUESTED'
                 WHEN EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RuntimeCounterCount]>1) THEN 'AVAILABLE'
                 ELSE 'THREAD_DETAIL_NOT_PRESENT' END,
            'PLAN_XML',N'Threaddetails werden nur bei expliziter Anforderung ausgegeben.';
        INSERT [#ExecutionPlanAnalysis_Capabilities]
        SELECT @AnalysisObjectId,'PSP_VARIANT',CONVERT(bit,CASE WHEN (@PlanXml.exist('//*[@QueryVariantID]')=1 OR @PlanXml.exist('//*[@QueryVariantId]')=1) THEN 1 ELSE 0 END),
            CASE WHEN (@PlanXml.exist('//*[@QueryVariantID]')=1 OR @PlanXml.exist('//*[@QueryVariantId]')=1) THEN 'AVAILABLE' ELSE 'ELEMENT_NOT_PRESENT' END,
            'PLAN_XML',N'PSP-/Multiplanmerkmale werden anhand vorhandener XML-Attribute erkannt.';
        INSERT [#ExecutionPlanAnalysis_Capabilities]
        SELECT @AnalysisObjectId,'OPPO_VARIANT',CONVERT(bit,CASE WHEN @PlanXml.exist('//*[local-name(.)="OptionalPredicate"]')=1 THEN 1 ELSE 0 END),
            CASE WHEN @PlanXml.exist('//*[local-name(.)="OptionalPredicate"]')=1 THEN 'AVAILABLE' ELSE 'ELEMENT_NOT_PRESENT' END,
            'PLAN_XML',N'OPPO wird nur bei tatsächlich vorhandenem OptionalPredicate-Element ausgewiesen.';

        /* Explizite Planwarnungen. */
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT
              @AnalysisObjectId
            , CASE WHEN [EarlyAbortReason]=N'TimeOut' THEN 'OPTIMIZER_TIMEOUT' ELSE 'OPTIMIZER_EARLY_ABORT' END
            , 'COMPILE'
            , CASE WHEN [EarlyAbortReason]=N'TimeOut' THEN 'HIGH' ELSE 'INFO' END
            , 'COMPILE_WARNING','PLAN_XML',[StatementOrdinal],[StatementId],NULL,NULL,NULL
            , 'EARLY_ABORT_REASON',NULL,NULL,NULL,'EXPLICIT_PLAN_ATTRIBUTE',@WorkloadProfile
            , N'Die Optimierung wurde vor Abschluss des vollständigen Suchraums beendet.'
            , CONCAT(N'Reason=',[EarlyAbortReason])
            , N'GoodEnoughPlanFound kann normal sein; TimeOut ist ein Vertiefungshinweis, aber kein Beweis eines schlechten Plans.'
            , NULL,N'Compilezeit, Joinkomplexität und Query-Store-Historie prüfen.'
        FROM [#ExecutionPlanAnalysis_Statements]
        WHERE [AnalysisObjectId]=@AnalysisObjectId AND [EarlyAbortReason] IS NOT NULL;

        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT
              @AnalysisObjectId,'NO_JOIN_PREDICATE','JOIN','HIGH','COMPILE_WARNING','PLAN_XML'
            , [st].[StatementOrdinal],[st].[StatementId]
            , TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , NULLIF([r].[n].value('string((@PhysicalOp)[1])','nvarchar(128)'),N'')
            , NULLIF([r].[n].value('string((@LogicalOp)[1])','nvarchar(128)'),N'')
            , NULL,NULL,NULL,NULL,'EXPLICIT_PLAN_WARNING',@WorkloadProfile
            , N'Ein Joinoperator besitzt laut Plan keine Joinbedingung.'
            , N'Warnings/@NoJoinPredicate=1.'
            , N'Ein fachlich beabsichtigtes kartesisches Produkt ist möglich.'
            , NULL,N'Querytext und erwartete Ergebnismenge prüfen.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        WHERE [r].[n].exist('./*[local-name(.)="Warnings"][@NoJoinPredicate="1"]')=1;

        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT
              @AnalysisObjectId,'PLAN_AFFECTING_CONVERT','PREDICATE','HIGH','COMPILE_WARNING','PLAN_XML'
            , [st].[StatementOrdinal],[st].[StatementId],NULL,NULL,NULL,NULL,NULL,NULL,NULL
            , 'EXPLICIT_PLAN_WARNING',@WorkloadProfile
            , N'Eine implizite Konvertierung kann Seek- oder Kardinalitätsentscheidungen beeinflussen.'
            , LEFT(CONCAT(N'Issue=',[p].[n].value('string((@ConvertIssue)[1])','nvarchar(256)'),N'; Expression=',[p].[n].value('string((@Expression)[1])','nvarchar(3000)')),4000)
            , N'Nicht jede implizite Konvertierung beeinflusst den Zugriff; die PlanAffectingConvert-Warnung besitzt höhere Evidenz als ein bloßer ScalarString-Treffer.'
            , NULL,N'Datentypen auf Spalten- und Parameterseite vergleichen.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="PlanAffectingConvert"]') AS [p]([n]);

        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT
              @AnalysisObjectId,'COLUMN_WITHOUT_STATISTICS','STATISTICS','HIGH','COMPILE_WARNING','PLAN_XML'
            , [st].[StatementOrdinal],[st].[StatementId],NULL,NULL,NULL,NULL,NULL,NULL,NULL
            , 'EXPLICIT_PLAN_WARNING',@WorkloadProfile
            , N'Der Plan meldet eine Spaltenreferenz ohne verfügbare Statistik.'
            , N'ColumnsWithNoStatistics wurde im Plan gespeichert.'
            , N'Die Ursache kann Sichtbarkeit, temporäre Struktur oder Featuresemantik sein; ein Statistik-Create ist keine automatische Folgerung.'
            , NULL,N'Objektart, Spaltenrolle und aktuelle Statistikmetadaten prüfen.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        WHERE [st].[StatementXml].exist('.//*[local-name(.)="ColumnsWithNoStatistics"]')=1;

        /* Spills sind explizite Runtimeevidenz. */
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT
              @AnalysisObjectId
            , CASE WHEN [SpillKind] LIKE '%Hash%' THEN 'HASH_SPILL'
                   WHEN [SpillKind] LIKE '%Sort%' THEN 'SORT_SPILL'
                   WHEN [SpillKind] LIKE '%Exchange%' THEN 'EXCHANGE_SPILL'
                   ELSE 'TEMPDB_SPILL' END
            , 'TEMPDB','HIGH','EXPLICIT_RUNTIME_WARNING','PLAN_XML'
            , [m].[StatementOrdinal],[m].[StatementId],[m].[NodeId]
            , [o].[PhysicalOp],[o].[LogicalOp]
            , 'SPILLED_DATA_SIZE',[m].[SpilledDataSize],'source unit',NULL,'EXPLICIT_PLAN_WARNING',@WorkloadProfile
            , N'Ein Operator hat während der erfassten Ausführung nach tempdb ausgelagert.'
            , CONCAT(N'SpillKind=',[m].[SpillKind],N'; SpillLevel=',COALESCE(CONVERT(nvarchar(30),[m].[SpillLevel]),N'<NULL>'))
            , N'Ein kleiner einmaliger Spill muss nicht die Hauptursache sein; Menge, Wiederholung, Grant und Gesamtlaufzeit gemeinsam bewerten.'
            , NULL,N'Memory Grant, Kardinalität und STATISTICS IO/TIME korrelieren.'
        FROM [#ExecutionPlanAnalysis_MemoryAndSpills] AS [m]
        LEFT JOIN [#ExecutionPlanAnalysis_Operators] AS [o]
          ON [o].[AnalysisObjectId]=[m].[AnalysisObjectId]
         AND [o].[StatementOrdinal]=[m].[StatementOrdinal]
         AND [o].[NodeId]=[m].[NodeId]
        WHERE [m].[AnalysisObjectId]=@AnalysisObjectId AND [m].[RecordType]='SPILL';

        /* Workloadabhängige Cardinality-, Rows-Read-, Lookup- und Scanregeln. */
        ;WITH [Candidate] AS
        (
            SELECT [r].*,[o].[PhysicalOp],[o].[LogicalOp]
            FROM [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
            JOIN [#ExecutionPlanAnalysis_Operators] AS [o]
              ON [o].[AnalysisObjectId]=[r].[AnalysisObjectId]
             AND [o].[StatementOrdinal]=[r].[StatementOrdinal]
             AND [o].[NodeId]=[r].[NodeId]
            WHERE [r].[AnalysisObjectId]=@AnalysisObjectId
              AND [r].[ActualToEstimatedRatio] IS NOT NULL
        ),
        [Matched] AS
        (
            SELECT [c].*,[t].[Severity],[t].[MinRatio],[t].[MinAbsoluteRows],
                   ROW_NUMBER() OVER
                   (PARTITION BY [c].[StatementOrdinal],[c].[NodeId]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [Candidate] AS [c]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='CARDINALITY_UNDERESTIMATE'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [c].[ActualToEstimatedRatio]>=[t].[MinRatio]
             AND ABS(COALESCE([c].[ActualRows],0)-COALESCE([c].[EstimatedRowsTotal],0))>=COALESCE([t].[MinAbsoluteRows],0)
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'CARDINALITY_UNDERESTIMATE','CARDINALITY',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],
               'ACTUAL_TO_ESTIMATED_RATIO',[ActualToEstimatedRatio],'ratio',[MinRatio],'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Der Operator lieferte wesentlich mehr Zeilen als für seine gesamte Ausführungszahl geschätzt.',
               CONCAT(N'EstimatedTotal=',[EstimatedRowsTotal],N'; Actual=',[ActualRows]),
               N'Die Gesamtabschätzung verwendet EstimateExecutions beziehungsweise Rebind-/Rewind-Angaben als dokumentierte Näherung.',
               NULL,N'Ersten ursächlichen Schätzfehler im Datenfluss, Statistiken und Parameterverteilung prüfen.'
        FROM [Matched] WHERE [rn]=1;

        ;WITH [Candidate] AS
        (
            SELECT [r].*,[o].[PhysicalOp],[o].[LogicalOp]
            FROM [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
            JOIN [#ExecutionPlanAnalysis_Operators] AS [o]
              ON [o].[AnalysisObjectId]=[r].[AnalysisObjectId]
             AND [o].[StatementOrdinal]=[r].[StatementOrdinal]
             AND [o].[NodeId]=[r].[NodeId]
            WHERE [r].[AnalysisObjectId]=@AnalysisObjectId
              AND [r].[ActualToEstimatedRatio] IS NOT NULL
        ),
        [Matched] AS
        (
            SELECT [c].*,[t].[Severity],[t].[MaxRatio],[t].[MinAbsoluteRows],
                   ROW_NUMBER() OVER
                   (PARTITION BY [c].[StatementOrdinal],[c].[NodeId]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [Candidate] AS [c]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='CARDINALITY_OVERESTIMATE'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [c].[ActualToEstimatedRatio]<=[t].[MaxRatio]
             AND ABS(COALESCE([c].[ActualRows],0)-COALESCE([c].[EstimatedRowsTotal],0))>=COALESCE([t].[MinAbsoluteRows],0)
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'CARDINALITY_OVERESTIMATE','CARDINALITY',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],
               'ACTUAL_TO_ESTIMATED_RATIO',[ActualToEstimatedRatio],'ratio',[MaxRatio],'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Der Operator lieferte wesentlich weniger Zeilen als für seine gesamte Ausführungszahl geschätzt.',
               CONCAT(N'EstimatedTotal=',[EstimatedRowsTotal],N'; Actual=',[ActualRows]),
               N'Die Gesamtabschätzung verwendet EstimateExecutions beziehungsweise Rebind-/Rewind-Angaben als dokumentierte Näherung.',
               NULL,N'Memory Grant, Joinwahl, Statistiken und Parameterverteilung prüfen.'
        FROM [Matched] WHERE [rn]=1;

        ;WITH [Matched] AS
        (
            SELECT [a].*,[t].[Severity],[t].[MinRowsRead],[t].[MinRowsNotReturned],[t].[MinRowsNotReturnedPercent],
                   ROW_NUMBER() OVER
                   (PARTITION BY [a].[StatementOrdinal],[a].[NodeId]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [#ExecutionPlanAnalysis_AccessPaths] AS [a]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='ROWS_READ_NOT_RETURNED'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [a].[ActualRowsRead]>=COALESCE([t].[MinRowsRead],0)
             AND [a].[RowsReadNotReturned]>=COALESCE([t].[MinRowsNotReturned],0)
             AND [a].[RowsReadNotReturnedPercent]>=COALESCE([t].[MinRowsNotReturnedPercent],0)
            WHERE [a].[AnalysisObjectId]=@AnalysisObjectId
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'ROWS_READ_NOT_RETURNED','ACCESS_PATH',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],
               'ROWS_READ_NOT_RETURNED_PERCENT',[RowsReadNotReturnedPercent],'percent',[MinRowsNotReturnedPercent],
               'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Der Access-Operator las wesentlich mehr Zeilen als er weitergab.',
               CONCAT(N'RowsRead=',[ActualRowsRead],N'; RowsReturned=',[ActualRows],N'; NotReturned=',[RowsReadNotReturned]),
               N'Nur gepaarte ActualRows-/ActualRowsRead-Counter werden verwendet. Das Finding heißt nur bei nachgewiesenem Predicate ResidualDiscard.',
               NULL,N'Seek- und Residual-Predicate, Indexschlüsselreihenfolge und Selektivität prüfen.'
        FROM [Matched] WHERE [rn]=1;

        ;WITH [Matched] AS
        (
            SELECT [a].*,[t].[Severity],[t].[MinExecutionCount],
                   ROW_NUMBER() OVER
                   (PARTITION BY [a].[StatementOrdinal],[a].[NodeId]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [#ExecutionPlanAnalysis_AccessPaths] AS [a]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='LOOKUP_HIGH_EXECUTIONS'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [a].[ActualExecutions]>=COALESCE([t].[MinExecutionCount],0)
            WHERE [a].[AnalysisObjectId]=@AnalysisObjectId AND [a].[IsLookup]=1
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'LOOKUP_HIGH_EXECUTIONS','ACCESS_PATH',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],
               'ACTUAL_EXECUTIONS',CONVERT(decimal(38,4),[ActualExecutions]),'executions',CONVERT(decimal(38,4),[MinExecutionCount]),
               'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Ein Lookup wurde in der erfassten Ausführung sehr häufig aufgerufen.',
               CONCAT(N'ActualExecutions=',[ActualExecutions],N'; ActualRowsRead=',[ActualRowsRead]),
               N'Lookupexistenz allein ist kein Problem; die Bewertung erfordert tatsächliche Wiederholung und Arbeit.',
               NULL,N'Coverage, Indexbreite, DML-Kosten und alternative Joinformen prüfen.'
        FROM [Matched] WHERE [rn]=1;

        ;WITH [Matched] AS
        (
            SELECT [a].*,[t].[Severity],[t].[MinRowsRead],
                   ROW_NUMBER() OVER
                   (PARTITION BY [a].[StatementOrdinal],[a].[NodeId]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [#ExecutionPlanAnalysis_AccessPaths] AS [a]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='LARGE_SCAN'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [a].[ActualRowsRead]>=COALESCE([t].[MinRowsRead],0)
            WHERE [a].[AnalysisObjectId]=@AnalysisObjectId AND [a].[PhysicalOp] LIKE N'%Scan%'
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'LARGE_SCAN_HIGH_WORK','ACCESS_PATH',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],
               'ACTUAL_ROWS_READ',[ActualRowsRead],'rows',[MinRowsRead],
               'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Ein Scan verarbeitete eine für das Workloadprofil relevante Datenmenge.',
               CONCAT(N'ActualRowsRead=',[ActualRowsRead],N'; ActualRows=',[ActualRows]),
               N'Ein großer Scan kann bei Batch-, Reporting- oder Wartungsworkloads optimal sein.',
               NULL,N'STATISTICS IO, Rückgabeanteil, Partition Elimination und Columnstore-Eignung prüfen.'
        FROM [Matched] WHERE [rn]=1;

        /* Memory Grant: Vollauslastung allein ist kein Undergrantbeweis. */
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'MEMORY_GRANT_WAIT','MEMORY','HIGH','RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],NULL,NULL,NULL,'GRANT_WAIT_MS',CONVERT(decimal(38,4),[GrantWaitTimeMs]),'ms',0,
               'EXPLICIT_RUNTIME_VALUE',@WorkloadProfile,
               N'Die erfasste Ausführung wartete auf den Memory Grant.',
               CONCAT(N'GrantWaitMs=',[GrantWaitTimeMs],N'; RequestedKB=',[RequestedMemoryKb],N'; GrantedKB=',[GrantedMemoryKb]),
               N'Ein isolierter kurzer Wait muss mit gleichzeitigem Server-Memorydruck korreliert werden.',
               NULL,N'Current Memory Grants, Resource Semaphore und Konkurrenzsituation prüfen.'
        FROM [#ExecutionPlanAnalysis_MemoryAndSpills]
        WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RecordType]='MEMORY_GRANT' AND COALESCE([GrantWaitTimeMs],0)>0;

        ;WITH [Matched] AS
        (
            SELECT [m].*,[t].[Severity],[t].[MinRatio],[t].[MinMemoryKb],
                   [GrantWasteRatio]=CONVERT(decimal(38,8),CONVERT(decimal(38,12),[m].[GrantedMemoryKb])
                      /NULLIF(CONVERT(decimal(38,12),[m].[MaxUsedMemoryKb]),CONVERT(decimal(38,12),0))),
                   ROW_NUMBER() OVER
                   (PARTITION BY [m].[StatementOrdinal]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [#ExecutionPlanAnalysis_MemoryAndSpills] AS [m]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='MEMORY_GRANT_OVER'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [m].[GrantedMemoryKb]>=COALESCE([t].[MinMemoryKb],0)
             AND [m].[MaxUsedMemoryKb]>0
             AND CONVERT(decimal(38,8),CONVERT(decimal(38,12),[m].[GrantedMemoryKb])
                 /NULLIF(CONVERT(decimal(38,12),[m].[MaxUsedMemoryKb]),CONVERT(decimal(38,12),0)))>=[t].[MinRatio]
            WHERE [m].[AnalysisObjectId]=@AnalysisObjectId AND [m].[RecordType]='MEMORY_GRANT'
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'MEMORY_GRANT_OVER','MEMORY',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],NULL,NULL,NULL,'GRANTED_TO_USED_RATIO',[GrantWasteRatio],'ratio',[MinRatio],
               'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Der gewährte Memory Grant lag deutlich über der maximal gemessenen Nutzung.',
               CONCAT(N'GrantedKB=',[GrantedMemoryKb],N'; MaxUsedKB=',[MaxUsedMemoryKb]),
               N'Ein einzelner Last-Actual-Plan bildet nur eine Ausführung ab; Memory Grant Feedback und Parameterstreuung können den Befund erklären.',
               NULL,N'Query-Store-Verteilung und Memory Grant Feedback prüfen.'
        FROM [Matched] WHERE [rn]=1;

        /* Parallel Thread Skew bei verfügbarer Threadverteilung. */
        ;WITH [ThreadStats] AS
        (
            SELECT
                  [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
                , [ThreadCount]=COUNT(*)
                , [TotalRows]=SUM(COALESCE([ActualRows],0))
                , [MaxRows]=MAX(COALESCE([ActualRows],0))
                , [AverageRows]=AVG(CONVERT(decimal(38,8),COALESCE([ActualRows],0)))
            FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime]
            WHERE [AnalysisObjectId]=@AnalysisObjectId
            GROUP BY [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
        ),
        [Matched] AS
        (
            SELECT [s].*,[o].[PhysicalOp],[o].[LogicalOp],[t].[Severity],[t].[MinRatio],[t].[MinAbsoluteRows],
                   [SkewRatio]=CONVERT(decimal(38,8),[s].[MaxRows]/NULLIF([s].[AverageRows],0)),
                   ROW_NUMBER() OVER
                   (PARTITION BY [s].[StatementOrdinal],[s].[NodeId]
                    ORDER BY CASE [t].[Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END DESC) [rn]
            FROM [ThreadStats] AS [s]
            JOIN [#ExecutionPlanAnalysis_Operators] AS [o]
              ON [o].[AnalysisObjectId]=[s].[AnalysisObjectId]
             AND [o].[StatementOrdinal]=[s].[StatementOrdinal]
             AND [o].[NodeId]=[s].[NodeId]
            JOIN [monitor].[PlanAnalysisRuleThreshold] AS [t]
              ON [t].[RuleCode]='PARALLEL_THREAD_SKEW'
             AND [t].[ProfileCode]=@WorkloadProfile AND [t].[IsEnabled]=1
             AND [s].[ThreadCount]>=COALESCE(TRY_CONVERT(int,JSON_VALUE([t].[AdditionalConfigurationJson],'$.minimumThreads')),4)
             AND [s].[TotalRows]>=COALESCE([t].[MinAbsoluteRows],0)
             AND CONVERT(decimal(38,8),[s].[MaxRows]/NULLIF([s].[AverageRows],0))>=[t].[MinRatio]
        )
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'PARALLEL_THREAD_SKEW','PARALLELISM',[Severity],'RUNTIME_MEASURED','PLAN_XML',
               [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],
               'MAX_TO_AVERAGE_THREAD_ROWS',[SkewRatio],'ratio',[MinRatio],
               'PlanAnalysisRuleThreshold',@WorkloadProfile,
               N'Die Zeilenarbeit war zwischen parallelen Workerthreads stark ungleich verteilt.',
               CONCAT(N'Threads=',[ThreadCount],N'; TotalRows=',[TotalRows],N'; MaxRows=',[MaxRows],N'; AverageRows=',[AverageRows]),
               N'Threadwerte können bei kurzen oder partiellen Live-Plänen unvollständig sein.',
               NULL,N'Partitionierungs-/Hashverteilung, Predicate-Skew und Exchange-Operatoren prüfen.'
        FROM [Matched] WHERE [rn]=1;

        /* Sortoperatoren werden als Review, nicht als automatischer Indexfehler bewertet. */
        INSERT [#ExecutionPlanAnalysis_Findings]
        (
              [AnalysisObjectId],[FindingCode],[Category],[Severity],[Confidence]
            , [EvidenceLevel],[StatementOrdinal],[StatementId],[NodeId]
            , [PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
            , [ThresholdValue],[ThresholdSource],[WorkloadProfile]
            , [Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
        )
        SELECT @AnalysisObjectId,'INDEX_ORDER_REVIEW','INDEX_ORDER',
               CASE WHEN COALESCE([r].[ActualRows],[o].[EstimateRows])>=1000000 THEN 'MEDIUM' ELSE 'INFO' END,
               CASE WHEN [r].[ActualRows] IS NULL THEN 'COMPILE_HEURISTIC' ELSE 'RUNTIME_INFERRED' END,
               CASE WHEN [r].[ActualRows] IS NULL THEN 'PLAN_XML_ESTIMATE' ELSE 'PLAN_XML_RUNTIME' END,
               [o].[StatementOrdinal],[o].[StatementId],[o].[NodeId],[o].[PhysicalOp],[o].[LogicalOp],
               'SORT_ROWS',COALESCE([r].[ActualRows],[o].[EstimateRows]),'rows',NULL,'STRUCTURAL_REVIEW',@WorkloadProfile,
               N'Ein Sortoperator zeigt eine benötigte Reihenfolge, die vom direkten Eingabepfad nicht garantiert wurde.',
               CONCAT(N'Rows=',COALESCE(CONVERT(nvarchar(100),[r].[ActualRows]),CONVERT(nvarchar(100),[o].[EstimateRows]))),
               N'Daraus folgt nicht automatisch, dass ein Index falsch sortiert ist; Gleichheitspräfix, ASC/DESC, Backward Scan, andere Workloads und DML-Kosten fehlen möglicherweise.',
               NULL,N'Sort Keys mit Indexschlüsselreihenfolge und ScanDirection vergleichen.'
        FROM [#ExecutionPlanAnalysis_Operators] AS [o]
        LEFT JOIN [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
          ON [r].[AnalysisObjectId]=[o].[AnalysisObjectId]
         AND [r].[StatementOrdinal]=[o].[StatementOrdinal]
         AND [r].[NodeId]=[o].[NodeId]
        WHERE [o].[AnalysisObjectId]=@AnalysisObjectId AND [o].[PhysicalOp]=N'Sort';

        IF @MitThreadRuntime=0
            DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId;

        /*
          DIAG-005: Die normalisierten Resultsets werden ausschließlich aus
          bereits materialisierter Plan-, Runtime- und Cacheevidenz abgeleitet.
          Der Plan wird hier weder erneut beschafft noch erneut als Ganzes
          zerlegt; die Statement-XML-Fragmente sind Teil desselben Shreddinglaufs.
        */
        INSERT [#ExecutionPlanAnalysis_PlanWarnings]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [WarningCode],[WarningCategory],[Severity],[EvidenceKind],[EvidenceSource]
            , [PlanSource],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown]
            , [IsMeasured],[IsInferred],[MetricName],[MetricValue],[MetricUnit]
            , [Detail],[FalsePositiveGuard],[StatusCode]
        )
        SELECT
              @AnalysisObjectId,[f].[StatementOrdinal],[f].[StatementId],[f].[NodeId]
            , [f].[FindingCode],[f].[Category],[f].[Severity],[f].[Confidence],[f].[EvidenceLevel]
            , @PlanSource,@SourceObservedAtUtc
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN [f].[Confidence]='EXPLICIT_RUNTIME_WARNING' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN [f].[Confidence]='EXPLICIT_RUNTIME_WARNING' THEN 0 ELSE 1 END)
            , [f].[MetricName],[f].[MetricValue],[f].[MetricUnit]
            , [f].[Evidence],[f].[EvidenceLimit],'AVAILABLE'
        FROM [#ExecutionPlanAnalysis_Findings] AS [f]
        WHERE [f].[AnalysisObjectId]=@AnalysisObjectId
          AND [f].[Confidence] IN ('COMPILE_WARNING','EXPLICIT_RUNTIME_WARNING');

        IF NOT EXISTS
           (
               SELECT 1
               FROM [#ExecutionPlanAnalysis_PlanWarnings]
               WHERE [AnalysisObjectId]=@AnalysisObjectId
           )
            INSERT [#ExecutionPlanAnalysis_PlanWarnings]
            (
                  [AnalysisObjectId],[WarningCode],[WarningCategory],[Severity]
                , [EvidenceKind],[EvidenceSource],[PlanSource],[SourceObservedAtUtc]
                , [IsCurrent],[IsLastKnown],[IsMeasured],[IsInferred]
                , [Detail],[FalsePositiveGuard],[StatusCode]
            )
            VALUES
            (
                  @AnalysisObjectId,'NO_EXPLICIT_WARNING','SOURCE_STATUS','INFO'
                , 'SOURCE_STATUS','PLAN_XML',@PlanSource,@SourceObservedAtUtc
                , CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END
                , CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END
                , 0,0
                , N'Das analysierte Plan-XML enthält keine unterstützte explizite Warnung.'
                , N'Keine Warnung bedeutet nicht, dass der Plan optimal ist; nur explizite und eng belegte Warnungsmuster werden hier normalisiert.'
                , 'AVAILABLE'
            );

        INSERT [#ExecutionPlanAnalysis_OptimizerContext]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[PlanSource],[RuntimeCounterScope]
            , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown]
            , [OptimizationLevel],[EarlyAbortReason],[CardinalityEstimationModelVersion]
            , [StatementSubTreeCost],[StatementEstimatedRows]
            , [CompileTimeMs],[CompileCpuMs],[CompileMemoryKb]
            , [RetrievedFromCache],[NonParallelPlanReason],[PlanDegreeOfParallelism]
            , [PlanGenerationNum],[CacheCreationTime],[CacheLastExecutionTime],[CacheExecutionCount]
            , [CacheObjectType],[CacheObjectClass],[CacheUseCounts],[CacheRefCounts]
            , [CacheSizeBytes],[CachePoolId],[SetOptions],[CompileUserId],[DatabaseId]
            , [EvidenceMeasurement],[StatusCode],[FalsePositiveGuard]
        )
        SELECT
              @AnalysisObjectId,[s].[StatementOrdinal],[s].[StatementId],@PlanSource,@RuntimeCounterScope
            , @SourceObservedAtUtc
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END)
            , [s].[OptimizationLevel],[s].[EarlyAbortReason],[s].[CardinalityEstimationModelVersion]
            , [s].[StatementSubTreeCost],[s].[StatementEstimatedRows]
            , [s].[CompileTimeMs],[s].[CompileCpuMs],[s].[CompileMemoryKb]
            , [s].[RetrievedFromCache],[s].[NonParallelPlanReason]
            , TRY_CONVERT(int,NULLIF([x].[StatementXml].value(
                  'string((.//*[local-name(.)="QueryPlan"]/@DegreeOfParallelism)[1])','nvarchar(100)'),N''))
            , [c].[PlanGenerationNum],[c].[CacheCreationTime],[c].[CacheLastExecutionTime],[c].[ExecutionCount]
            , [c].[CacheObjectType],[c].[CacheObjectClass],[c].[CacheUseCounts],[c].[CacheRefCounts]
            , [c].[CacheSizeBytes],[c].[CachePoolId],[c].[SetOptions],[c].[CompileUserId],[c].[DatabaseId]
            , CASE WHEN [c].[StatusCode]='AVAILABLE' THEN 'PLAN_AND_CACHE_MEASURED' ELSE 'PLAN_MEASURED' END
            , CASE WHEN [c].[StatusCode] IS NULL THEN 'PLAN_ONLY'
                   WHEN [c].[StatusCode]='AVAILABLE' THEN 'AVAILABLE'
                   ELSE [c].[StatusCode] END
            , N'Optimizer- und Cacheattribute beschreiben die beobachtete Kompilierung beziehungsweise einen flüchtigen Cachezustand; sie beweisen allein keine Regressionsursache.'
        FROM [#ExecutionPlanAnalysis_Statements] AS [s]
        JOIN [#InternalAnalyzeExecutionPlan_StatementXml] AS [x]
          ON [x].[StatementOrdinal]=[s].[StatementOrdinal]
        OUTER APPLY
        (
            SELECT TOP (1) *
            FROM [#ExecutionPlanAnalysis_SourceContext]
            WHERE [AnalysisObjectId]=@AnalysisObjectId
            ORDER BY [SourceCapturedAtUtc] DESC
        ) AS [c]
        WHERE [s].[AnalysisObjectId]=@AnalysisObjectId;

        INSERT [#ExecutionPlanAnalysis_RuntimeFeedback]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [FeedbackType],[FeedbackState],[MetricName],[ObservedValue],[BaselineValue]
            , [DeltaRatio],[MetricUnit],[RuntimeCounterScope],[EvidenceSource]
            , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
            , [StatusCode],[EvidenceLimit]
        )
        SELECT
              @AnalysisObjectId,[r].[StatementOrdinal],[r].[StatementId],[r].[NodeId]
            , 'CARDINALITY_OBSERVATION',[r].[RuntimeMetricStatus]
            , 'ACTUAL_TO_ESTIMATED_ROWS',[r].[ActualRows],[r].[EstimatedRowsTotal]
            , [r].[ActualToEstimatedRatio],'ratio',@RuntimeCounterScope,'PLAN_XML_RUNTIME'
            , @SourceObservedAtUtc
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END)
            , 1,1,'AVAILABLE'
            , N'Die Abweichung gilt nur für den erfassten Runtime-Scope und wird nicht als dauerhafte Kardinalitätsregression verallgemeinert.'
        FROM [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
        WHERE [r].[AnalysisObjectId]=@AnalysisObjectId
          AND [r].[RuntimeCounterCount]>0
          AND [r].[ActualRows] IS NOT NULL
          AND [r].[EstimatedRowsTotal] IS NOT NULL;

        INSERT [#ExecutionPlanAnalysis_RuntimeFeedback]
        (
              [AnalysisObjectId],[StatementOrdinal],[StatementId],[NodeId]
            , [FeedbackType],[FeedbackState],[MetricName],[ObservedValue],[BaselineValue]
            , [DeltaRatio],[MetricUnit],[RuntimeCounterScope],[EvidenceSource]
            , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
            , [StatusCode],[EvidenceLimit]
        )
        SELECT
              @AnalysisObjectId,[m].[StatementOrdinal],[m].[StatementId],[m].[NodeId]
            , CASE WHEN [m].[RecordType]='MEMORY_GRANT' THEN 'MEMORY_GRANT_OBSERVATION' ELSE 'SPILL_OBSERVATION' END
            , COALESCE([m].[MemoryGrantFeedbackState],[m].[SpillKind])
            , CASE WHEN [m].[RecordType]='MEMORY_GRANT' THEN 'GRANTED_MEMORY_KB' ELSE 'SPILLED_DATA_SIZE' END
            , CONVERT(decimal(38,4),CASE WHEN [m].[RecordType]='MEMORY_GRANT' THEN [m].[GrantedMemoryKb] ELSE [m].[SpilledDataSize] END)
            , CONVERT(decimal(38,4),CASE WHEN [m].[RecordType]='MEMORY_GRANT' THEN [m].[MaxUsedMemoryKb] END)
            , CASE WHEN [m].[RecordType]='MEMORY_GRANT' AND COALESCE([m].[MaxUsedMemoryKb],0)>0
                   THEN CONVERT(decimal(38,8),CONVERT(decimal(38,12),[m].[GrantedMemoryKb])
                        /NULLIF(CONVERT(decimal(38,12),[m].[MaxUsedMemoryKb]),0)) END
            , CASE WHEN [m].[RecordType]='MEMORY_GRANT' THEN 'KB' ELSE 'source unit' END
            , @RuntimeCounterScope,'PLAN_XML_RUNTIME',@SourceObservedAtUtc
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END)
            , 1,CONVERT(bit,CASE WHEN [m].[RecordType]='MEMORY_GRANT' THEN 1 ELSE 0 END)
            , 'AVAILABLE'
            , N'Memory-Grant- und Spillwerte gelten nur für den erfassten Plan; Wiederholung und Workloadverteilung bleiben außerhalb dieser Evidenz.'
        FROM [#ExecutionPlanAnalysis_MemoryAndSpills] AS [m]
        WHERE [m].[AnalysisObjectId]=@AnalysisObjectId;

        IF NOT EXISTS
           (
               SELECT 1
               FROM [#ExecutionPlanAnalysis_RuntimeFeedback]
               WHERE [AnalysisObjectId]=@AnalysisObjectId
           )
            INSERT [#ExecutionPlanAnalysis_RuntimeFeedback]
            (
                  [AnalysisObjectId],[FeedbackType],[FeedbackState],[RuntimeCounterScope]
                , [EvidenceSource],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown]
                , [IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
            )
            VALUES
            (
                  @AnalysisObjectId,'SOURCE_STATUS','NO_RUNTIME_COUNTERS',@RuntimeCounterScope
                , 'PLAN_XML',@SourceObservedAtUtc
                , CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END
                , CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END
                , 0,0,CASE WHEN @RuntimeCounterScope='NONE' THEN 'NOT_COLLECTED' ELSE 'AVAILABLE' END
                , N'Ohne passende Runtimecounter werden keine Laufzeitdeltas abgeleitet.'
            );

        INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
        (
              [AnalysisObjectId],[RecordType],[FeatureType],[StatementOrdinal],[StatementId],[NodeId]
            , [QueryVariantId],[FeatureState],[DataHandlingStatus],[EvidenceSource]
            , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
            , [StatusCode],[EvidenceLimit]
        )
        SELECT
              @AnalysisObjectId,'PLAN_FEATURE',[v].[FeatureType],[st].[StatementOrdinal],[st].[StatementId],[v].[NodeId]
            , [v].[QueryVariantId],[v].[FeatureState],'NO_SENSITIVE_PAYLOAD','PLAN_XML'
            , @SourceObservedAtUtc
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END)
            , 1,0,'AVAILABLE'
            , N'Die Zeile belegt nur das im Plan sichtbare Feature beziehungsweise dessen Zustand; Wirksamkeit und Nutzen müssen über mehrere Ausführungen geprüft werden.'
        FROM [#InternalAnalyzeExecutionPlan_StatementXml] AS [st]
        CROSS APPLY
        (
            SELECT
                  'PARAMETER_SENSITIVE_PLAN' AS [FeatureType]
                , TRY_CONVERT(int,NULLIF([st].[StatementXml].value(
                    'string((.//*[@QueryVariantID][1]/@QueryVariantID)[1])','nvarchar(100)'),N'')) AS [QueryVariantId]
                , CONVERT(nvarchar(128),N'DISPATCHER_OR_VARIANT') AS [FeatureState]
                , CONVERT(int,NULL) AS [NodeId]
            WHERE [st].[StatementXml].exist('.//*[local-name(.)="ParameterSensitivePredicate" or @QueryVariantID]')=1
            UNION ALL
            SELECT 'MEMORY_GRANT_FEEDBACK',NULL,
                   NULLIF([st].[StatementXml].value(
                     'string((.//*[local-name(.)="MemoryGrantInfo"]/@IsMemoryGrantFeedbackAdjusted)[1])','nvarchar(128)'),N''),NULL
            WHERE [st].[StatementXml].exist('.//*[local-name(.)="MemoryGrantInfo"][@IsMemoryGrantFeedbackAdjusted]')=1
            UNION ALL
            SELECT 'ADAPTIVE_JOIN',NULL,N'PRESENT',
                   TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(100)'),N''))
            FROM [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"][@PhysicalOp="Adaptive Join"]') AS [r]([n])
            UNION ALL
            SELECT 'BATCH_MODE',NULL,N'PRESENT',
                   TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(100)'),N''))
            FROM [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"][@EstimatedExecutionMode="Batch" or @ActualExecutionMode="Batch"]') AS [r]([n])
        ) AS [v];

        IF NOT EXISTS
           (
               SELECT 1
               FROM [#ExecutionPlanAnalysis_FeedbackAndVariants]
               WHERE [AnalysisObjectId]=@AnalysisObjectId
           )
            INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
            (
                  [AnalysisObjectId],[RecordType],[FeatureType],[FeatureState]
                , [DataHandlingStatus],[EvidenceSource],[SourceObservedAtUtc]
                , [IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
            )
            VALUES
            (
                  @AnalysisObjectId,'SOURCE_STATUS','NO_SUPPORTED_FEATURE',N'NOT_PRESENT'
                , 'NO_SENSITIVE_PAYLOAD','PLAN_XML',@SourceObservedAtUtc
                , CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END
                , CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END
                , 0,0,'AVAILABLE'
                , N'Nicht vorhandene Featuremarker schließen versions- oder kontextabhängige Optimizerfunktionen außerhalb dieses Plans nicht aus.'
            );

        DECLARE @MinSeverityRank int=CASE @MinSeverity WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END;
        DELETE FROM [#ExecutionPlanAnalysis_PlanWarnings]
        WHERE [AnalysisObjectId]=@AnalysisObjectId
          AND [WarningCode]<>'NO_EXPLICIT_WARNING'
          AND CASE [Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END<@MinSeverityRank;
        DELETE FROM [#ExecutionPlanAnalysis_Findings]
        WHERE [AnalysisObjectId]=@AnalysisObjectId
          AND CASE [Severity] WHEN 'CRITICAL' THEN 5 WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END<@MinSeverityRank;

        IF NOT EXISTS
           (
               SELECT 1
               FROM [#ExecutionPlanAnalysis_PlanWarnings]
               WHERE [AnalysisObjectId]=@AnalysisObjectId
           )
            INSERT [#ExecutionPlanAnalysis_PlanWarnings]
            (
                  [AnalysisObjectId],[WarningCode],[WarningCategory],[Severity]
                , [EvidenceKind],[EvidenceSource],[PlanSource],[SourceObservedAtUtc]
                , [IsCurrent],[IsLastKnown],[IsMeasured],[IsInferred]
                , [Detail],[FalsePositiveGuard],[StatusCode]
            )
            VALUES
            (
                  @AnalysisObjectId,'NO_WARNING_AT_OR_ABOVE_THRESHOLD','SOURCE_STATUS','INFO'
                , 'SOURCE_STATUS','PLAN_XML',@PlanSource,@SourceObservedAtUtc
                , CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 1 ELSE 0 END
                , CASE WHEN @RuntimeCounterScope='LAST_COMPLETED_EXECUTION' THEN 1 ELSE 0 END
                , 0,0
                , CONCAT(N'Unterhalb der angeforderten Mindestschwere ',@MinSeverity,N' vorhandene Warnungen wurden nicht ausgegeben.')
                , N'Ein gefiltertes Warnungsresultset beweist weder einen optimalen Plan noch eine fehlende Planquelle.'
                , 'AVAILABLE'
            );

        DECLARE @ShowplanVersion nvarchar(64)=NULLIF(@PlanXml.value('string((/*[local-name(.)="ShowPlanXML"]/@Version)[1])','nvarchar(64)'),N'');
        DECLARE @ShowplanBuild nvarchar(64)=NULLIF(@PlanXml.value('string((/*[local-name(.)="ShowPlanXML"]/@Build)[1])','nvarchar(64)'),N'');
        DECLARE @HasRuntime bit=CONVERT(bit,CASE WHEN EXISTS
            (SELECT 1 FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [AnalysisObjectId]=@AnalysisObjectId AND [RuntimeCounterCount]>0) THEN 1 ELSE 0 END);
        DECLARE @StatementCount int=(SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Statements] WHERE [AnalysisObjectId]=@AnalysisObjectId);
        DECLARE @OperatorCount int=(SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Operators] WHERE [AnalysisObjectId]=@AnalysisObjectId);
        DECLARE @CeVersion int=(SELECT MAX([CardinalityEstimationModelVersion]) FROM [#ExecutionPlanAnalysis_Statements] WHERE [AnalysisObjectId]=@AnalysisObjectId);
        DECLARE @PlanHash varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(nvarchar(max),@PlanXml)));

        UPDATE [#ExecutionPlanAnalysis_ParameterEvidence]
        SET [PlanDocumentHash]=CONVERT(nvarchar(66),@PlanHash,1)
        WHERE [CandidateId]=@AnalysisObjectId;

        INSERT [#ExecutionPlanAnalysis_PlanDocuments]
        (
              [AnalysisObjectId],[PlanSource],[RuntimeCounterScope]
            , [ShowplanVersion],[ShowplanBuild],[SourceProductVersion]
            , [SourceCompatibilityLevel],[CardinalityEstimationModelVersion]
            , [IsPlanComplete],[PlanDocumentHash],[StatementCount]
            , [OperatorCount],[HasRuntimeCounters]
        )
        VALUES
        (
              @AnalysisObjectId,@PlanSource,@RuntimeCounterScope
            , @ShowplanVersion,@ShowplanBuild,NULL,NULL,@CeVersion
            , CONVERT(bit,CASE WHEN @RuntimeCounterScope='CURRENT_PARTIAL_EXECUTION' THEN 0 ELSE 1 END)
            , @PlanHash,@StatementCount,@OperatorCount,@HasRuntime
        );

        IF @IsPartialOut=1 AND @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;
END;
GO
-- END SOURCE: Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql

-- BEGIN SOURCE: Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql
/*
===============================================================================
Objekt       : monitor.USP_CreateExecutionEvidenceJson
Version      : 1.0.2
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Erzeugt und validiert ein versioniertes Execution-Evidence-JSON
               aus Plan-XML, bereits erfassten STATISTICS IO/TIME-Meldungen und
               optional zielgerichteter Statistik-/Histogrammevidenz.
Sicherheit   : Führt niemals übergebenes SQL aus. Histogramm-, Parameter- und
               Predicatewerte werden standardmäßig DERIVED_ONLY verarbeitet.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml                       xml             = NULL
    , @StatisticsIoText              nvarchar(max)   = NULL
    , @StatisticsTimeText            nvarchar(max)   = NULL
    , @StatisticsLanguage            varchar(16)     = 'AUTO'
    , @StatisticsEvidenceJson        nvarchar(max)   = NULL
    , @ObjectMetadataJson            nvarchar(max)   = NULL
    , @StatistikEvidenzModus         varchar(16)     = 'PLAN_ONLY'
    , @HistogrammModus               varchar(16)     = 'NONE'
    , @MetadatenQuellenmodus         varchar(16)     = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt       bit             = 0
    , @EvidenzDatenschutzModus       varchar(24)     = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus    varchar(16)     = 'RAW'
    , @SensitiveDataConfirmed        bit             = 0
    , @MitPredicateHistogramMap      bit             = 1
    , @StatementId                   int             = NULL
    , @StatementOrdinal              int             = NULL
    , @SameExecutionAsPlanConfirmed  bit             = NULL
    , @CapturedAtUtc                 datetime2(3)    = NULL
    , @SourceProductVersion          nvarchar(128)   = NULL
    , @SourceCompatibilityLevel      smallint        = NULL
    , @SourceEngineEdition           int             = NULL
    , @MaxStatistiken                int             = 100
    , @MaxHistogrammSchritte         int             = 20000
    , @LockTimeoutMs                 int             = 0
    , @HighImpactConfirmed           bit             = 0
    , @AdditionalEvidenceJson        nvarchar(max)   = NULL
    , @ExistingEvidenceJson          nvarchar(max)   = NULL
    , @RawTextHandling               varchar(16)     = 'HASH_ONLY'
    , @StrictValidation              bit             = 1
    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 1
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
    , @StatusCodeOut                 varchar(40)     = NULL OUTPUT
    , @IsPartialOut                  bit             = NULL OUTPUT
    , @ErrorNumberOut                int             = NULL OUTPUT
    , @ErrorMessageOut               nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @StatisticsMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'PLAN_ONLY'))));
    DECLARE @HistogramMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))));
    DECLARE @MetadataSourceMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MetadatenQuellenmodus,'EVIDENCE_ONLY'))));
    DECLARE @PrivacyMode varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@EvidenzDatenschutzModus,'DERIVED_ONLY'))));
    DECLARE @IdentifierMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@IdentifierDatenschutzModus,'RAW'))));
    DECLARE @RawMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@RawTextHandling,'HASH_ONLY'))));
    DECLARE @GeneratedAtUtc datetime2(3)=COALESCE(@CapturedAtUtc,SYSUTCDATETIME());
    DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);
    DECLARE @SameExecutionConfidence varchar(40)=CASE
        WHEN @SameExecutionAsPlanConfirmed=1 THEN 'CONFIRMED'
        WHEN @SameExecutionAsPlanConfirmed=0 THEN 'UNCONFIRMED'
        ELSE 'UNCONFIRMED' END;

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CreateExecutionEvidenceJson';
        PRINT N'Erzeugt Evidence JSON aus optionalem PlanXml, STATISTICS IO/TIME und zielgerichteten Statistikmetadaten; führt kein SQL aus.';
        PRINT N'@StatistikEvidenzModus NONE|PLAN_ONLY|USED|RELEVANT|OBJECT_ALL; aktuelle Metadaten benötigen CURRENT_SERVER und bestätigte Quellumgebung.';
        PRINT N'@HistogrammModus NONE|SUMMARY|STEPS. @EvidenzDatenschutzModus DERIVED_ONLY (Default)|TOKENIZED|STRUCTURE_ONLY|RAW.';
        PRINT N'RAW benötigt @SensitiveDataConfirmed=1. @IdentifierDatenschutzModus RAW|TOKENIZED|OMIT.';
        PRINT N'@RawTextHandling NONE|HASH_ONLY|INCLUDE. INCLUDE benötigt @SensitiveDataConfirmed=1 und @IdentifierDatenschutzModus=RAW.';
        PRINT N'Der Generator führt die analysierte Query niemals selbst aus.';
        RETURN;
    END;

    CREATE TABLE [#CreateExecutionEvidenceJson_TableMap]
    (
          [ResultName] sysname NOT NULL
        , [TargetTable] sysname NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_CaptureStatus]
    (
          [ModuleName] sysname NOT NULL
        , [GeneratedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [SchemaVersion] int NOT NULL
        , [StatisticsIoRowCount] bigint NOT NULL
        , [StatisticsTimeRowCount] bigint NOT NULL
        , [PlanStatisticsUsageCount] bigint NOT NULL
        , [CurrentStatisticsCount] bigint NOT NULL
        , [HistogramStepCount] bigint NOT NULL
        , [PredicateMappingCount] bigint NOT NULL
        , [EvidencePrivacyMode] varchar(24) NOT NULL
        , [IdentifierPrivacyMode] varchar(16) NOT NULL
        , [SameExecutionConfidence] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsIo]
    (
          [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[ObjectOrdinal] int NOT NULL
        , [ObjectDisplayName] nvarchar(512) NULL,[ScanCount] bigint NULL,[LogicalReads] bigint NULL
        , [PhysicalReads] bigint NULL,[PageServerReads] bigint NULL,[ReadAheadReads] bigint NULL
        , [PageServerReadAheadReads] bigint NULL,[LobLogicalReads] bigint NULL,[LobPhysicalReads] bigint NULL
        , [LobPageServerReads] bigint NULL,[LobReadAheadReads] bigint NULL,[LobPageServerReadAheadReads] bigint NULL
        , [LanguageDetected] varchar(16) NOT NULL,[ParseStatus] varchar(40) NOT NULL,[RawLine] nvarchar(4000) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsTime]
    (
          [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[TimeCategory] varchar(24) NOT NULL
        , [CpuMs] bigint NULL,[ElapsedMs] bigint NULL,[LanguageDetected] varchar(16) NOT NULL
        , [ParseStatus] varchar(40) NOT NULL,[RawLine] nvarchar(4000) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
    (
          [StatisticsUsageOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL
        , [StatementId] int NULL,[StatementCompId] int NULL
        , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[StatisticsName] sysname NULL
        , [LastUpdateAtCompile] datetime2(7) NULL,[ModificationCountAtCompile] bigint NULL
        , [SamplingPercentAtCompile] decimal(19,6) NULL,[SourceElement] nvarchar(128) NOT NULL,[ParseStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_ObjectReferences]
    (
          [ReferenceOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[StatementId] int NULL,[StatementCompId] int NULL
        , [NodeId] int NULL,[ReferenceType] varchar(40) NOT NULL,[ReferenceSource] varchar(40) NOT NULL
        , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[IndexName] sysname NULL
        , [AliasName] sysname NULL,[StorageType] nvarchar(128) NULL,[PlanObjectId] int NULL,[PlanIndexId] int NULL
        , [IsTemporaryObject] bit NOT NULL,[IsTableVariable] bit NOT NULL,[IsRemoteObject] bit NOT NULL,[IsDmlTarget] bit NOT NULL
        , [ResolutionCapability] varchar(40) NOT NULL,[SourceElement] nvarchar(128) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsCurrent]
    (
          [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[ObjectId] int NOT NULL
        , [StatisticsName] sysname NOT NULL,[StatisticsId] int NOT NULL,[IsIndexStatistics] bit NOT NULL
        , [IsAutoCreated] bit NULL,[IsUserCreated] bit NULL,[IsFiltered] bit NULL,[FilterDefinition] nvarchar(max) NULL
        , [NoRecompute] bit NULL,[IsIncremental] bit NULL,[HasPersistedSample] bit NULL,[LeadingColumnName] sysname NULL
        , [LastUpdated] datetime2(7) NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[SamplePercent] decimal(19,6) NULL
        , [Steps] int NULL,[UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,6) NULL
        , [PersistedSamplePercent] float NULL,[CollectionStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_HistogramSteps]
    (
          [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL
        , [StatisticsName] sysname NOT NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname NULL
        , [StepOrdinal] int NOT NULL,[RangeHighKeyRaw] nvarchar(4000) NULL
        , [RangeRows] float NULL,[EqualRows] float NULL,[DistinctRangeRows] bigint NULL,[AverageRangeRows] float NULL
        , [IsPredicateTarget] bit NULL,[PredicateMatchCount] int NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_HistogramSummary]
    (
          [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL
        , [StatisticsName] sysname NOT NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname NULL
        , [HistogramSteps] int NOT NULL,[HistogramEstimatedRows] float NULL,[MaxEqualRows] float NULL
        , [MaxRangeRows] float NULL,[MaxStepRows] float NULL,[DominantStepPercent] decimal(19,6) NULL
        , [TailStepRows] float NULL,[TailStepPercent] decimal(19,6) NULL,[CollectionStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
    (
          [PredicateReferenceId] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[NodeId] int NULL
        , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ColumnName] sysname NULL
        , [StatisticsName] sysname NULL,[PredicateKind] varchar(40) NULL,[ValueSource] varchar(32) NOT NULL
        , [MappingStatus] varchar(48) NOT NULL,[MappingConfidence] varchar(16) NOT NULL,[MatchedStepOrdinal] int NULL
        , [MatchesRangeHighKey] bit NOT NULL,[IsBelowHistogram] bit NOT NULL,[IsAboveHistogram] bit NOT NULL
        , [SensitiveValueStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_CollectionStatus]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[StatisticsName] sysname NULL
        , [StatusCode] varchar(40) NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_Warnings]
    (
          [WarningCode] varchar(80) NOT NULL
        , [Severity] varchar(16) NOT NULL
        , [Detail] nvarchar(2048) NOT NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @StatisticsMode NOT IN ('NONE','PLAN_ONLY','USED','RELEVANT','OBJECT_ALL')
       OR @HistogramMode NOT IN ('NONE','SUMMARY','STEPS')
       OR @MetadataSourceMode NOT IN ('EVIDENCE_ONLY','CURRENT_SERVER')
       OR @PrivacyMode NOT IN ('DERIVED_ONLY','TOKENIZED','RAW','STRUCTURE_ONLY')
       OR @IdentifierMode NOT IN ('RAW','TOKENIZED','OMIT')
       OR @RawMode NOT IN ('NONE','HASH_ONLY','INCLUDE')
       OR @StrictValidation NOT IN (0,1) OR @JsonErzeugen NOT IN (0,1)
       OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @SourceCompatibilityLevel IS NOT NULL AND @SourceCompatibilityLevel NOT BETWEEN 80 AND 200
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Modus-, Grenzwert-, Ausgabe-, Datenschutz- oder Versionsparameter.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @PrivacyMode='RAW' AND @SensitiveDataConfirmed<>1
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'RAW-Evidenz kann Parameter-, Predicate-, Filter- oder Histogrammwerte enthalten und benötigt @SensitiveDataConfirmed=1.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @RawMode='INCLUDE'
       AND (@SensitiveDataConfirmed<>1 OR @IdentifierMode<>'RAW')
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'Rohtext kann sensible Werte und nicht zuverlässig einzeln anonymisierbare Identifikatoren enthalten. INCLUDE benötigt @SensitiveDataConfirmed=1 und @IdentifierDatenschutzModus=RAW.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @MetadataSourceMode='CURRENT_SERVER'
       AND @QuellumgebungBestaetigt<>1
    BEGIN
        SELECT @StatusCodeOut='SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'CURRENT_SERVER-Anreicherung benötigt @QuellumgebungBestaetigt=1.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @HistogramMode<>'NONE'
       AND (@MetadataSourceMode<>'CURRENT_SERVER' OR @StatisticsMode IN ('NONE','PLAN_ONLY'))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Histogramme benötigen CURRENT_SERVER und Statistikmodus USED, RELEVANT oder OBJECT_ALL.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'captureStatus|statisticsIo|statisticsTime|planStatisticsUsage|objectReferences|currentStatistics|histogramSummaries|histogramSteps|predicateHistogramMappings|collectionStatus|warnings'
            , @MappingTable=N'#CreateExecutionEvidenceJson_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCodeOut='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.';
    END;
    IF @ConsoleResultRequested=1 SET @OutputMode='NONE';

    IF @StatusCodeOut='AVAILABLE'
    BEGIN TRY
        INSERT [#CreateExecutionEvidenceJson_StatisticsIo]
        SELECT * FROM [monitor].[TVF_ParseStatisticsIoText](@StatisticsIoText,@StatisticsLanguage);

        INSERT [#CreateExecutionEvidenceJson_StatisticsTime]
        SELECT * FROM [monitor].[TVF_ParseStatisticsTimeText](@StatisticsTimeText,@StatisticsLanguage);

        DECLARE @PlanStatementCount int=0;
        IF @PlanXml IS NOT NULL
        BEGIN
            SELECT @PlanStatementCount=COUNT(*)
            FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n]);

            IF @StatementOrdinal IS NOT NULL
            BEGIN
                UPDATE [#CreateExecutionEvidenceJson_StatisticsIo] SET [StatementOrdinal]=@StatementOrdinal WHERE [StatementOrdinal] IS NULL;
                UPDATE [#CreateExecutionEvidenceJson_StatisticsTime] SET [StatementOrdinal]=@StatementOrdinal WHERE [StatementOrdinal] IS NULL;
            END
            ELSE IF @PlanStatementCount=1
            BEGIN
                UPDATE [#CreateExecutionEvidenceJson_StatisticsIo] SET [StatementOrdinal]=1 WHERE [StatementOrdinal] IS NULL;
                UPDATE [#CreateExecutionEvidenceJson_StatisticsTime] SET [StatementOrdinal]=1 WHERE [StatementOrdinal] IS NULL;
            END
            ELSE IF @PlanStatementCount>1 AND (EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsIo]) OR EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsTime]))
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('AMBIGUOUS_STATEMENT_MAPPING','MEDIUM',N'STATISTICS IO/TIME wurde für einen Mehrstatementplan ohne explizite @StatementOrdinal übergeben. Die Werte bleiben planbezogen.');
                SET @IsPartialOut=1;
            END;

            IF @StatisticsMode<>'NONE'
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
                SELECT * FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml,@StatementId);
            END;

            INSERT [#CreateExecutionEvidenceJson_ObjectReferences]
            SELECT * FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml,@StatementId);
        END;

        IF @StatisticsEvidenceJson IS NOT NULL AND ISJSON(@StatisticsEvidenceJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51021,N'@StatisticsEvidenceJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_STATISTICS_EVIDENCE_JSON','MEDIUM',N'Externes Statistik-Evidenz-JSON wurde verworfen.');
            SET @IsPartialOut=1;
        END;
        IF @ObjectMetadataJson IS NOT NULL AND ISJSON(@ObjectMetadataJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51022,N'@ObjectMetadataJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_OBJECT_METADATA_JSON','MEDIUM',N'Externes Objektmetadaten-JSON wurde verworfen.');
            SET @IsPartialOut=1;
        END;
        IF @AdditionalEvidenceJson IS NOT NULL AND ISJSON(@AdditionalEvidenceJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51023,N'@AdditionalEvidenceJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_ADDITIONAL_EVIDENCE_JSON','MEDIUM',N'Zusätzliche Evidenz wurde verworfen.');
            SET @IsPartialOut=1;
        END;
        IF @ExistingEvidenceJson IS NOT NULL AND ISJSON(@ExistingEvidenceJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51024,N'@ExistingEvidenceJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_EXISTING_EVIDENCE_JSON','MEDIUM',N'Bestehende Evidenz wurde verworfen.');
            SET @IsPartialOut=1;
        END;

        /* Separate Statistik- und Objektpayloads werden in eine kanonische
           Evidence-Hülle überführt. Explizit übergebene Teilpayloads haben
           Vorrang vor gleichnamigen Abschnitten aus @ExistingEvidenceJson. */
        DECLARE @CanonicalEvidenceJson nvarchar(max)=
            CASE WHEN @ExistingEvidenceJson IS NOT NULL AND ISJSON(@ExistingEvidenceJson)=1
                 THEN @ExistingEvidenceJson ELSE N'{}' END;

        IF @StatisticsEvidenceJson IS NOT NULL AND ISJSON(@StatisticsEvidenceJson)=1
        BEGIN
            DECLARE @StatisticsSection nvarchar(max)=JSON_QUERY(@StatisticsEvidenceJson,N'$.statistics');
            IF @StatisticsSection IS NULL AND LEFT(LTRIM(@StatisticsEvidenceJson),1)=N'{'
                SET @StatisticsSection=JSON_QUERY(@StatisticsEvidenceJson);
            IF @StatisticsSection IS NULL
            BEGIN
                IF @StrictValidation=1 THROW 51021,N'@StatisticsEvidenceJson muss ein JSON-Objekt mit Statistikabschnitten enthalten.',1;
                INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_STATISTICS_EVIDENCE_SHAPE','MEDIUM',N'Externes Statistik-Evidenz-JSON besitzt keine unterstützte Objektstruktur.');
                SET @IsPartialOut=1;
            END
            ELSE
                SET @CanonicalEvidenceJson=JSON_MODIFY(@CanonicalEvidenceJson,N'$.statistics',JSON_QUERY(@StatisticsSection));
        END;

        IF @ObjectMetadataJson IS NOT NULL AND ISJSON(@ObjectMetadataJson)=1
        BEGIN
            DECLARE @ObjectSection nvarchar(max)=JSON_QUERY(@ObjectMetadataJson,N'$.objectReferences');
            IF @ObjectSection IS NULL AND LEFT(LTRIM(@ObjectMetadataJson),1)=N'['
                SET @ObjectSection=JSON_QUERY(@ObjectMetadataJson);
            IF @ObjectSection IS NULL
            BEGIN
                IF @StrictValidation=1 THROW 51022,N'@ObjectMetadataJson muss ein JSON-Array oder objectReferences enthalten.',1;
                INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_OBJECT_METADATA_SHAPE','MEDIUM',N'Externes Objektmetadaten-JSON besitzt keine unterstützte Arraystruktur.');
                SET @IsPartialOut=1;
            END
            ELSE
                SET @CanonicalEvidenceJson=JSON_MODIFY(@CanonicalEvidenceJson,N'$.objectReferences',JSON_QUERY(@ObjectSection));
        END;

        /* Bestehende kanonische Evidenz wird strukturell zusammengeführt. Plan-
           referenzen werden bei vorhandenem @PlanXml neu und damit eindeutiger
           aufgebaut; bereits erfasste IO-/TIME-Werte bleiben erhalten. */
        IF ISJSON(@CanonicalEvidenceJson)=1
        BEGIN
            INSERT [#CreateExecutionEvidenceJson_StatisticsIo]
            SELECT [StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],[ObjectDisplayName],
                   [ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],
                   [PageServerReadAheadReads],[LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],
                   [LobReadAheadReads],[LobPageServerReadAheadReads],[LanguageDetected],[ParseStatus],NULL
            FROM OPENJSON(@CanonicalEvidenceJson,N'$.statisticsIo')
            WITH
            (
                  [StatementOrdinal] int N'$.statementOrdinal',[MessageOrdinal] int N'$.messageOrdinal'
                , [ObjectOrdinal] int N'$.objectOrdinal',[ObjectDisplayName] nvarchar(512) N'$.objectDisplayName'
                , [ScanCount] bigint N'$.scanCount',[LogicalReads] bigint N'$.logicalReads'
                , [PhysicalReads] bigint N'$.physicalReads',[PageServerReads] bigint N'$.pageServerReads'
                , [ReadAheadReads] bigint N'$.readAheadReads',[PageServerReadAheadReads] bigint N'$.pageServerReadAheadReads'
                , [LobLogicalReads] bigint N'$.lobLogicalReads',[LobPhysicalReads] bigint N'$.lobPhysicalReads'
                , [LobPageServerReads] bigint N'$.lobPageServerReads',[LobReadAheadReads] bigint N'$.lobReadAheadReads'
                , [LobPageServerReadAheadReads] bigint N'$.lobPageServerReadAheadReads'
                , [LanguageDetected] varchar(16) N'$.languageDetected',[ParseStatus] varchar(40) N'$.parseStatus'
            );

            INSERT [#CreateExecutionEvidenceJson_StatisticsTime]
            SELECT [StatementOrdinal],[MessageOrdinal],[TimeCategory],[CpuMs],[ElapsedMs],[LanguageDetected],[ParseStatus],NULL
            FROM OPENJSON(@CanonicalEvidenceJson,N'$.statisticsTime')
            WITH
            (
                  [StatementOrdinal] int N'$.statementOrdinal',[MessageOrdinal] int N'$.messageOrdinal'
                , [TimeCategory] varchar(24) N'$.timeCategory',[CpuMs] bigint N'$.cpuMs'
                , [ElapsedMs] bigint N'$.elapsedMs',[LanguageDetected] varchar(16) N'$.languageDetected'
                , [ParseStatus] varchar(40) N'$.parseStatus'
            );

            IF @PlanXml IS NULL
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
                SELECT [StatisticsUsageOrdinal],[StatementOrdinal],[StatementId],[StatementCompId],
                       [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[LastUpdateAtCompile],
                       [ModificationCountAtCompile],[SamplingPercentAtCompile],[SourceElement],[ParseStatus]
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.planUsage')
                WITH
                (
                      [StatisticsUsageOrdinal] bigint N'$.statisticsUsageOrdinal',[StatementOrdinal] int N'$.statementOrdinal'
                    , [StatementId] int N'$.statementId',[StatementCompId] int N'$.statementCompId'
                    , [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
                    , [LastUpdateAtCompile] datetime2(7) N'$.lastUpdateAtCompile'
                    , [ModificationCountAtCompile] bigint N'$.modificationCountAtCompile'
                    , [SamplingPercentAtCompile] decimal(19,6) N'$.samplingPercentAtCompile'
                    , [SourceElement] nvarchar(128) N'$.sourceElement',[ParseStatus] varchar(40) N'$.parseStatus'
                );


                INSERT [#CreateExecutionEvidenceJson_ObjectReferences]
                SELECT [ReferenceOrdinal],[StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
                       [ReferenceType],[ReferenceSource],[DatabaseName],[SchemaName],[ObjectName],[IndexName],
                       [AliasName],[StorageType],[PlanObjectId],[PlanIndexId],[IsTemporaryObject],
                       [IsTableVariable],[IsRemoteObject],[IsDmlTarget],[ResolutionCapability],[SourceElement]
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.objectReferences')
                WITH
                (
                      [ReferenceOrdinal] bigint N'$.referenceOrdinal',[StatementOrdinal] int N'$.statementOrdinal'
                    , [StatementId] int N'$.statementId',[StatementCompId] int N'$.statementCompId',[NodeId] int N'$.nodeId'
                    , [ReferenceType] varchar(40) N'$.referenceType',[ReferenceSource] varchar(40) N'$.referenceSource'
                    , [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[IndexName] sysname N'$.indexName'
                    , [AliasName] sysname N'$.aliasName',[StorageType] nvarchar(128) N'$.storageType'
                    , [PlanObjectId] int N'$.planObjectId',[PlanIndexId] int N'$.planIndexId'
                    , [IsTemporaryObject] bit N'$.isTemporaryObject',[IsTableVariable] bit N'$.isTableVariable'
                    , [IsRemoteObject] bit N'$.isRemoteObject',[IsDmlTarget] bit N'$.isDmlTarget'
                    , [ResolutionCapability] varchar(40) N'$.resolutionCapability',[SourceElement] nvarchar(128) N'$.sourceElement'
                );
            END;

            IF @MetadataSourceMode<>'CURRENT_SERVER'
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_StatisticsCurrent]
                SELECT *
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.currentSnapshot')
                WITH
                (
                      [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[ObjectId] int N'$.objectId'
                    , [StatisticsName] sysname N'$.statisticsName',[StatisticsId] int N'$.statisticsId'
                    , [IsIndexStatistics] bit N'$.isIndexStatistics',[IsAutoCreated] bit N'$.isAutoCreated'
                    , [IsUserCreated] bit N'$.isUserCreated',[IsFiltered] bit N'$.isFiltered'
                    , [FilterDefinition] nvarchar(max) N'$.filterDefinition',[NoRecompute] bit N'$.noRecompute'
                    , [IsIncremental] bit N'$.isIncremental',[HasPersistedSample] bit N'$.hasPersistedSample'
                    , [LeadingColumnName] sysname N'$.leadingColumnName',[LastUpdated] datetime2(7) N'$.lastUpdated'
                    , [Rows] bigint N'$.rows',[RowsSampled] bigint N'$.rowsSampled'
                    , [SamplePercent] decimal(19,6) N'$.samplePercent',[Steps] int N'$.steps'
                    , [UnfilteredRows] bigint N'$.unfilteredRows',[ModificationCounter] bigint N'$.modificationCounter'
                    , [ModificationPercent] decimal(19,6) N'$.modificationPercent'
                    , [PersistedSamplePercent] float N'$.persistedSamplePercent',[CollectionStatus] varchar(40) N'$.collectionStatus'
                );

                INSERT [#CreateExecutionEvidenceJson_HistogramSummary]
                SELECT *
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.histogramSummaries')
                WITH
                (
                      [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
                    , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
                    , [HistogramSteps] int N'$.histogramSteps',[HistogramEstimatedRows] float N'$.histogramEstimatedRows'
                    , [MaxEqualRows] float N'$.maxEqualRows',[MaxRangeRows] float N'$.maxRangeRows'
                    , [MaxStepRows] float N'$.maxStepRows',[DominantStepPercent] decimal(19,6) N'$.dominantStepPercent'
                    , [TailStepRows] float N'$.tailStepRows',[TailStepPercent] decimal(19,6) N'$.tailStepPercent'
                    , [CollectionStatus] varchar(40) N'$.collectionStatus'
                );

                INSERT [#CreateExecutionEvidenceJson_HistogramSteps]
                SELECT [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatisticsId],[LeadingColumnName],
                       [StepOrdinal],CASE WHEN @PrivacyMode IN ('RAW','TOKENIZED') THEN [RangeHighKey] END,[RangeRows],[EqualRows],
                       [DistinctRangeRows],[AverageRangeRows],[IsPredicateTarget],[PredicateMatchCount]
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.histogramSteps')
                WITH
                (
                      [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
                    , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
                    , [StepOrdinal] int N'$.stepOrdinal',[RangeHighKey] nvarchar(4000) N'$.rangeHighKey'
                    , [RangeRows] float N'$.rangeRows',[EqualRows] float N'$.equalRows'
                    , [DistinctRangeRows] bigint N'$.distinctRangeRows',[AverageRangeRows] float N'$.averageRangeRows'
                    , [IsPredicateTarget] bit N'$.isPredicateTarget',[PredicateMatchCount] int N'$.predicateMatchCount'
                );

                INSERT [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
                SELECT [PredicateReferenceId],[StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName],
                       [ColumnName],[StatisticsName],[PredicateKind],[ValueSource],[MappingStatus],[MappingConfidence],
                       [MatchedStepOrdinal],COALESCE([MatchesRangeHighKey],0),COALESCE([IsBelowHistogram],0),
                       COALESCE([IsAboveHistogram],0),COALESCE([SensitiveValueStatus],'IMPORTED_DERIVED')
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.predicateHistogramMappings')
                WITH
                (
                      [PredicateReferenceId] bigint N'$.predicateReferenceId',[StatementOrdinal] int N'$.statementOrdinal'
                    , [NodeId] int N'$.nodeId',[DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[ColumnName] sysname N'$.columnName'
                    , [StatisticsName] sysname N'$.statisticsName',[PredicateKind] varchar(40) N'$.predicateKind'
                    , [ValueSource] varchar(32) N'$.valueSource',[MappingStatus] varchar(48) N'$.mappingStatus'
                    , [MappingConfidence] varchar(16) N'$.mappingConfidence',[MatchedStepOrdinal] int N'$.matchedStepOrdinal'
                    , [MatchesRangeHighKey] bit N'$.matchesRangeHighKey',[IsBelowHistogram] bit N'$.isBelowHistogram'
                    , [IsAboveHistogram] bit N'$.isAboveHistogram',[SensitiveValueStatus] varchar(40) N'$.sensitiveValueStatus'
                );
            END;
        END;

        IF @PlanXml IS NOT NULL
           AND @MetadataSourceMode='CURRENT_SERVER'
           AND @StatisticsMode IN ('USED','RELEVANT','OBJECT_ALL')
        BEGIN
            DECLARE @CollectionStatus varchar(40),@CollectionPartial bit,@CollectionError int,@CollectionMessage nvarchar(2048);
            EXEC [monitor].[InternalCollectExecutionPlanMetadata]
                  @PlanXml=@PlanXml
                , @StatistikEvidenzModus=@StatisticsMode
                , @HistogrammModus=@HistogramMode
                , @QuellumgebungBestaetigt=@QuellumgebungBestaetigt
                , @MitPredicateHistogramMap=@MitPredicateHistogramMap
                , @MaxStatistiken=@MaxStatistiken
                , @MaxHistogrammSchritte=@MaxHistogrammSchritte
                , @LockTimeoutMs=@LockTimeoutMs
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCodeOut=@CollectionStatus OUTPUT
                , @IsPartialOut=@CollectionPartial OUTPUT
                , @ErrorNumberOut=@CollectionError OUTPUT
                , @ErrorMessageOut=@CollectionMessage OUTPUT;

            IF @CollectionStatus<>'AVAILABLE'
            BEGIN
                SET @IsPartialOut=1;
                INSERT [#CreateExecutionEvidenceJson_Warnings]
                VALUES('CURRENT_METADATA_COLLECTION_LIMITED','MEDIUM',CONCAT(N'Status=',COALESCE(@CollectionStatus,N'<NULL>'),N'; ',COALESCE(@CollectionMessage,N'')));
            END;
        END;

        UPDATE [h]
        SET [h].[IsPredicateTarget]=CONVERT(bit,CASE WHEN [m].[PredicateMatchCount]>0 THEN 1 ELSE 0 END),
            [h].[PredicateMatchCount]=COALESCE([m].[PredicateMatchCount],0)
        FROM [#CreateExecutionEvidenceJson_HistogramSteps] AS [h]
        OUTER APPLY
        (
            SELECT COUNT(*) [PredicateMatchCount]
            FROM [#CreateExecutionEvidenceJson_PredicateHistogramMappings] AS [p]
            WHERE [p].[DatabaseName]=[h].[DatabaseName]
              AND [p].[SchemaName]=[h].[SchemaName]
              AND [p].[ObjectName]=[h].[ObjectName]
              AND [p].[StatisticsName]=[h].[StatisticsName]
              AND [p].[MatchedStepOrdinal]=[h].[StepOrdinal]
        ) AS [m];

        IF @RawMode<>'INCLUDE'
        BEGIN
            UPDATE [#CreateExecutionEvidenceJson_StatisticsIo] SET [RawLine]=NULL;
            UPDATE [#CreateExecutionEvidenceJson_StatisticsTime] SET [RawLine]=NULL;
        END;

        IF EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsIo] WHERE [ParseStatus]<>'PARSED')
           OR EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsTime] WHERE [ParseStatus]<>'PARSED')
        BEGIN
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('MESSAGE_PARSE_PARTIAL','LOW',N'Mindestens eine STATISTICS IO/TIME-Zeile konnte nur teilweise geparst werden.');
            SET @IsPartialOut=1;
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() BETWEEN 51021 AND 51024 THEN 'INVALID_EVIDENCE_JSON' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    IF @IsPartialOut=1 AND @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';

    /* Datenschutzgerechte Ausgabeprojektionen. Rohwerte bleiben nur bis hier lokal. */
    SELECT
          [StatementOrdinal],[MessageOrdinal],[ObjectOrdinal]
        , [ObjectDisplayName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectDisplayName]
             WHEN 'TOKENIZED' THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectDisplayName],N''))),1)
             ELSE NULL END
        , [ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],[PageServerReadAheadReads]
        , [LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],[LobReadAheadReads],[LobPageServerReadAheadReads]
        , [LanguageDetected],[ParseStatus],[RawLine]
    INTO [#CreateExecutionEvidenceJson_StatisticsIoOutput]
    FROM [#CreateExecutionEvidenceJson_StatisticsIo];

    SELECT * INTO [#CreateExecutionEvidenceJson_StatisticsTimeOutput] FROM [#CreateExecutionEvidenceJson_StatisticsTime];

    SELECT
          [StatisticsUsageOrdinal],[StatementOrdinal],[StatementId],[StatementCompId]
        , [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([DatabaseName],N''))),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([SchemaName],N''))),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectName],N''))),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([StatisticsName],N''))),1)) ELSE NULL END
        , [LastUpdateAtCompile],[ModificationCountAtCompile],[SamplingPercentAtCompile],[SourceElement],[ParseStatus]
    INTO [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput]
    FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsage];

    SELECT
          [ReferenceOrdinal],[StatementOrdinal],[StatementId],[StatementCompId],[NodeId],[ReferenceType],[ReferenceSource]
        , [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([DatabaseName],N''))),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([SchemaName],N''))),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectName],N''))),1)) ELSE NULL END
        , [IndexName]=CASE @IdentifierMode WHEN 'RAW' THEN [IndexName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([IndexName],N''))),1)) ELSE NULL END
        , [AliasName]=CASE @IdentifierMode WHEN 'RAW' THEN [AliasName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([AliasName],N''))),1)) ELSE NULL END
        , [StorageType],[PlanObjectId],[PlanIndexId],[IsTemporaryObject],[IsTableVariable],[IsRemoteObject],[IsDmlTarget]
        , [ResolutionCapability],[SourceElement]
    INTO [#CreateExecutionEvidenceJson_ObjectReferencesOutput]
    FROM [#CreateExecutionEvidenceJson_ObjectReferences];

    SELECT
          [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) ELSE NULL END
        , [ObjectId],[StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) ELSE NULL END
        , [StatisticsId],[IsIndexStatistics],[IsAutoCreated],[IsUserCreated],[IsFiltered]
        , [FilterDefinition]=CASE WHEN @PrivacyMode='RAW' THEN [FilterDefinition] END
        , [FilterDefinitionStatus]=CONVERT(varchar(40),CASE WHEN [IsFiltered]=0 THEN 'NOT_FILTERED' WHEN @PrivacyMode='RAW' THEN 'AVAILABLE_RAW' ELSE 'OMITTED_SENSITIVE' END)
        , [NoRecompute],[IsIncremental],[HasPersistedSample]
        , [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([LeadingColumnName],N''))),1)) ELSE NULL END
        , [LastUpdated],[Rows],[RowsSampled],[SamplePercent],[Steps],[UnfilteredRows]
        , [ModificationCounter],[ModificationPercent],[PersistedSamplePercent],[CollectionStatus]
    INTO [#CreateExecutionEvidenceJson_StatisticsCurrentOutput]
    FROM [#CreateExecutionEvidenceJson_StatisticsCurrent];

    SELECT
          [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) ELSE NULL END
        , [StatisticsId]
        , [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([LeadingColumnName],N''))),1)) ELSE NULL END
        , [HistogramSteps],[HistogramEstimatedRows],[MaxEqualRows],[MaxRangeRows],[MaxStepRows]
        , [DominantStepPercent],[TailStepRows],[TailStepPercent],[CollectionStatus]
    INTO [#CreateExecutionEvidenceJson_HistogramSummaryOutput]
    FROM [#CreateExecutionEvidenceJson_HistogramSummary];

    SELECT
          [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) ELSE NULL END
        , [StatisticsId]
        , [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([LeadingColumnName],N''))),1)) ELSE NULL END
        , [StepOrdinal]
        , [RangeHighKey]=CASE WHEN @PrivacyMode='RAW' THEN [RangeHighKeyRaw] END
        , [RangeHighKeyToken]=CASE WHEN @PrivacyMode='TOKENIZED' AND [RangeHighKeyRaw] IS NOT NULL
            THEN HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[RangeHighKeyRaw])) END
        , [RangeRows],[EqualRows],[DistinctRangeRows],[AverageRangeRows]
        , [IsPredicateTarget]=COALESCE([IsPredicateTarget],0),[PredicateMatchCount]=COALESCE([PredicateMatchCount],0)
        , [SensitiveValueStatus]=CONVERT(varchar(40),CASE @PrivacyMode WHEN 'RAW' THEN 'AVAILABLE_RAW'
             WHEN 'TOKENIZED' THEN 'TOKENIZED_CAPTURE_LOCAL' WHEN 'STRUCTURE_ONLY' THEN 'OMITTED_STRUCTURE_ONLY'
             ELSE 'OMITTED_DERIVED_ONLY' END)
    INTO [#CreateExecutionEvidenceJson_HistogramStepsOutput]
    FROM [#CreateExecutionEvidenceJson_HistogramSteps];

    SELECT
          [PredicateReferenceId],[StatementOrdinal],[NodeId]
        , [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([DatabaseName],N''))),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([SchemaName],N''))),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectName],N''))),1)) ELSE NULL END
        , [ColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [ColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ColumnName],N''))),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([StatisticsName],N''))),1)) ELSE NULL END
        , [PredicateKind],[ValueSource],[MappingStatus],[MappingConfidence],[MatchedStepOrdinal]
        , [MatchesRangeHighKey],[IsBelowHistogram],[IsAboveHistogram],[SensitiveValueStatus]
    INTO [#CreateExecutionEvidenceJson_PredicateMappingsOutput]
    FROM [#CreateExecutionEvidenceJson_PredicateHistogramMappings];

    INSERT [#CreateExecutionEvidenceJson_CaptureStatus]
    SELECT
          N'USP_CreateExecutionEvidenceJson',@GeneratedAtUtc,@StatusCodeOut,@IsPartialOut,1
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_StatisticsIoOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_StatisticsTimeOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_StatisticsCurrentOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_HistogramStepsOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_PredicateMappingsOutput])
        , @PrivacyMode,@IdentifierMode,@SameExecutionConfidence,@ErrorNumberOut,@ErrorMessageOut;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @PlanDocumentHash nvarchar(130)=CASE WHEN @PlanXml IS NOT NULL
            THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(nvarchar(max),@PlanXml))),1) END;
        DECLARE @MetaJson nvarchar(max)=(SELECT N'ExecutionEvidence' [resultName],1 [schemaVersion],N'USP_CreateExecutionEvidenceJson' [generator],N'1.0.0' [generatorVersion],@GeneratedAtUtc [generatedAtUtc],@StatusCodeOut [statusCode],@IsPartialOut [isPartial] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @CaptureJson nvarchar(max)=(SELECT @GeneratedAtUtc [capturedAtUtc],@SameExecutionAsPlanConfirmed [sameExecutionAsPlan],@SameExecutionConfidence [sameExecutionConfidence],@StatementOrdinal [statementOrdinal],@StatisticsLanguage [statisticsLanguage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @EnvironmentJson nvarchar(max)=(SELECT @SourceProductVersion [productVersion],@SourceCompatibilityLevel [compatibilityLevel],@SourceEngineEdition [engineEdition] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @IdentityJson nvarchar(max)=(SELECT @PlanDocumentHash [planDocumentHash],@StatementId [statementId] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @IoJson nvarchar(max)=(SELECT
              [StatementOrdinal] [statementOrdinal],[MessageOrdinal] [messageOrdinal],[ObjectOrdinal] [objectOrdinal]
            , [ObjectDisplayName] [objectDisplayName],[ScanCount] [scanCount],[LogicalReads] [logicalReads]
            , [PhysicalReads] [physicalReads],[PageServerReads] [pageServerReads],[ReadAheadReads] [readAheadReads]
            , [PageServerReadAheadReads] [pageServerReadAheadReads],[LobLogicalReads] [lobLogicalReads]
            , [LobPhysicalReads] [lobPhysicalReads],[LobPageServerReads] [lobPageServerReads]
            , [LobReadAheadReads] [lobReadAheadReads],[LobPageServerReadAheadReads] [lobPageServerReadAheadReads]
            , [LanguageDetected] [languageDetected],[ParseStatus] [parseStatus],[RawLine] [rawLine]
            FROM [#CreateExecutionEvidenceJson_StatisticsIoOutput] ORDER BY [MessageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @TimeJson nvarchar(max)=(SELECT
              [StatementOrdinal] [statementOrdinal],[MessageOrdinal] [messageOrdinal],[TimeCategory] [timeCategory]
            , [CpuMs] [cpuMs],[ElapsedMs] [elapsedMs],[LanguageDetected] [languageDetected]
            , [ParseStatus] [parseStatus],[RawLine] [rawLine]
            FROM [#CreateExecutionEvidenceJson_StatisticsTimeOutput] ORDER BY [MessageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @PlanStatsJson nvarchar(max)=(SELECT
              [StatisticsUsageOrdinal] [statisticsUsageOrdinal],[StatementOrdinal] [statementOrdinal]
            , [StatementId] [statementId],[StatementCompId] [statementCompId]
            , [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[LastUpdateAtCompile] [lastUpdateAtCompile]
            , [ModificationCountAtCompile] [modificationCountAtCompile]
            , [SamplingPercentAtCompile] [samplingPercentAtCompile],[SourceElement] [sourceElement]
            , [ParseStatus] [parseStatus]
            FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ObjectsJson nvarchar(max)=(SELECT
              [ReferenceOrdinal] [referenceOrdinal],[StatementOrdinal] [statementOrdinal]
            , [StatementId] [statementId],[StatementCompId] [statementCompId],[NodeId] [nodeId]
            , [ReferenceType] [referenceType],[ReferenceSource] [referenceSource]
            , [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [IndexName] [indexName],[AliasName] [aliasName],[StorageType] [storageType]
            , [PlanObjectId] [planObjectId],[PlanIndexId] [planIndexId]
            , [IsTemporaryObject] [isTemporaryObject],[IsTableVariable] [isTableVariable]
            , [IsRemoteObject] [isRemoteObject],[IsDmlTarget] [isDmlTarget]
            , [ResolutionCapability] [resolutionCapability],[SourceElement] [sourceElement]
            FROM [#CreateExecutionEvidenceJson_ObjectReferencesOutput] ORDER BY [StatementOrdinal],[ReferenceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @CurrentStatsJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [ObjectId] [objectId],[StatisticsName] [statisticsName],[StatisticsId] [statisticsId]
            , [IsIndexStatistics] [isIndexStatistics],[IsAutoCreated] [isAutoCreated],[IsUserCreated] [isUserCreated]
            , [IsFiltered] [isFiltered],[FilterDefinition] [filterDefinition],[FilterDefinitionStatus] [filterDefinitionStatus]
            , [NoRecompute] [noRecompute],[IsIncremental] [isIncremental],[HasPersistedSample] [hasPersistedSample]
            , [LeadingColumnName] [leadingColumnName],[LastUpdated] [lastUpdated],[Rows] [rows]
            , [RowsSampled] [rowsSampled],[SamplePercent] [samplePercent],[Steps] [steps]
            , [UnfilteredRows] [unfilteredRows],[ModificationCounter] [modificationCounter]
            , [ModificationPercent] [modificationPercent],[PersistedSamplePercent] [persistedSamplePercent]
            , [CollectionStatus] [collectionStatus]
            FROM [#CreateExecutionEvidenceJson_StatisticsCurrentOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramSummaryJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[StatisticsId] [statisticsId],[LeadingColumnName] [leadingColumnName]
            , [HistogramSteps] [histogramSteps],[HistogramEstimatedRows] [histogramEstimatedRows]
            , [MaxEqualRows] [maxEqualRows],[MaxRangeRows] [maxRangeRows],[MaxStepRows] [maxStepRows]
            , [DominantStepPercent] [dominantStepPercent],[TailStepRows] [tailStepRows]
            , [TailStepPercent] [tailStepPercent],[CollectionStatus] [collectionStatus]
            FROM [#CreateExecutionEvidenceJson_HistogramSummaryOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramStepsJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[StatisticsId] [statisticsId],[LeadingColumnName] [leadingColumnName]
            , [StepOrdinal] [stepOrdinal],[RangeHighKey] [rangeHighKey],[RangeHighKeyToken] [rangeHighKeyToken]
            , [RangeRows] [rangeRows],[EqualRows] [equalRows],[DistinctRangeRows] [distinctRangeRows]
            , [AverageRangeRows] [averageRangeRows],[IsPredicateTarget] [isPredicateTarget]
            , [PredicateMatchCount] [predicateMatchCount],[SensitiveValueStatus] [sensitiveValueStatus]
            FROM [#CreateExecutionEvidenceJson_HistogramStepsOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StepOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @MappingsJson nvarchar(max)=(SELECT
              [PredicateReferenceId] [predicateReferenceId],[StatementOrdinal] [statementOrdinal],[NodeId] [nodeId]
            , [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [ColumnName] [columnName],[StatisticsName] [statisticsName],[PredicateKind] [predicateKind]
            , [ValueSource] [valueSource],[MappingStatus] [mappingStatus],[MappingConfidence] [mappingConfidence]
            , [MatchedStepOrdinal] [matchedStepOrdinal],[MatchesRangeHighKey] [matchesRangeHighKey]
            , [IsBelowHistogram] [isBelowHistogram],[IsAboveHistogram] [isAboveHistogram]
            , [SensitiveValueStatus] [sensitiveValueStatus]
            FROM [#CreateExecutionEvidenceJson_PredicateMappingsOutput] ORDER BY [StatementOrdinal],[PredicateReferenceId],[ValueSource] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @StatusJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[StatusCode] [statusCode],[ErrorNumber] [errorNumber]
            , [ErrorMessage] [errorMessage]
            FROM [#CreateExecutionEvidenceJson_CollectionStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max)=(SELECT
              [WarningCode] [warningCode],[Severity] [severity],[Detail] [detail]
            FROM [#CreateExecutionEvidenceJson_Warnings] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RawInputJson nvarchar(max)=(SELECT
              LEN(@StatisticsIoText) [statisticsIoCharacters]
            , CASE WHEN @RawMode IN ('HASH_ONLY','INCLUDE') AND @StatisticsIoText IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StatisticsIoText)),1) END [statisticsIoHash]
            , LEN(@StatisticsTimeText) [statisticsTimeCharacters]
            , CASE WHEN @RawMode IN ('HASH_ONLY','INCLUDE') AND @StatisticsTimeText IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StatisticsTimeText)),1) END [statisticsTimeHash]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);

        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@MetaJson,N'{}')
            , N',"capture":',COALESCE(@CaptureJson,N'{}')
            , N',"sourceEnvironment":',COALESCE(@EnvironmentJson,N'{}')
            , N',"planIdentity":',COALESCE(@IdentityJson,N'{}')
            , N',"statisticsIo":',COALESCE(@IoJson,N'[]')
            , N',"statisticsTime":',COALESCE(@TimeJson,N'[]')
            , N',"statistics":{"planUsage":',COALESCE(@PlanStatsJson,N'[]')
            , N',"currentSnapshot":',COALESCE(@CurrentStatsJson,N'[]')
            , N',"histogramSummaries":',COALESCE(@HistogramSummaryJson,N'[]')
            , N',"histogramSteps":',COALESCE(@HistogramStepsJson,N'[]'),N'}'
            , N',"objectReferences":',COALESCE(@ObjectsJson,N'[]')
            , N',"predicateHistogramMappings":',COALESCE(@MappingsJson,N'[]')
            , N',"collectionStatus":',COALESCE(@StatusJson,N'[]')
            , N',"warnings":',COALESCE(@WarningsJson,N'[]')
            , N',"rawInput":',COALESCE(@RawInputJson,N'{}')
            , N',"importedEvidence":'
            , COALESCE
              (
                  (
                      SELECT
                            CONVERT(bit,CASE WHEN @StatisticsEvidenceJson IS NOT NULL THEN 1 ELSE 0 END) [statisticsEvidenceProvided]
                          , CASE WHEN @StatisticsEvidenceJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StatisticsEvidenceJson)),1) END [statisticsEvidenceHash]
                          , CONVERT(bit,CASE WHEN @ObjectMetadataJson IS NOT NULL THEN 1 ELSE 0 END) [objectMetadataProvided]
                          , CASE WHEN @ObjectMetadataJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ObjectMetadataJson)),1) END [objectMetadataHash]
                          , CONVERT(bit,CASE WHEN @ExistingEvidenceJson IS NOT NULL AND ISJSON(@ExistingEvidenceJson)=1 THEN 1 ELSE 0 END) [existingEvidenceMerged]
                          , CASE WHEN @ExistingEvidenceJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExistingEvidenceJson)),1) END [existingEvidenceHash]
                          , CONVERT(bit,CASE WHEN @AdditionalEvidenceJson IS NOT NULL THEN 1 ELSE 0 END) [additionalEvidenceProvided]
                          , CASE WHEN @AdditionalEvidenceJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@AdditionalEvidenceJson)),1) END [additionalEvidenceHash]
                      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
                  )
                , N'{}'
              )
            , N',"additionalEvidence":'
            , CASE WHEN @PrivacyMode='RAW' AND @SensitiveDataConfirmed=1
                   THEN COALESCE(JSON_QUERY(@AdditionalEvidenceJson),N'null') ELSE N'null' END
            , N'}'
        );
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#CreateExecutionEvidenceJson_CaptureStatus];
        SELECT * FROM [#CreateExecutionEvidenceJson_StatisticsIoOutput] ORDER BY [MessageOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_StatisticsTimeOutput] ORDER BY [MessageOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_ObjectReferencesOutput] ORDER BY [StatementOrdinal],[ReferenceOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_StatisticsCurrentOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName];
        SELECT * FROM [#CreateExecutionEvidenceJson_HistogramSummaryOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName];
        SELECT * FROM [#CreateExecutionEvidenceJson_HistogramStepsOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StepOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_PredicateMappingsOutput] ORDER BY [StatementOrdinal],[PredicateReferenceId],[ValueSource];
        SELECT * FROM [#CreateExecutionEvidenceJson_CollectionStatus];
        SELECT * FROM [#CreateExecutionEvidenceJson_Warnings];
    END;

    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CreateExecutionEvidenceJson_CaptureStatus'
            , @ResultLabel=N'Execution Evidence'
            , @EmptyMessage=N'Keine Evidenz erzeugt'
            , @StatusCode=@StatusCodeOut
            , @StatusMessage=@ErrorMessageOut;

    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [MapCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable] FROM [#CreateExecutionEvidenceJson_TableMap] ORDER BY [ResultName];
        OPEN [MapCursor];
        FETCH NEXT FROM [MapCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'captureStatus' THEN N'#CreateExecutionEvidenceJson_CaptureStatus'
                WHEN N'statisticsIo' THEN N'#CreateExecutionEvidenceJson_StatisticsIoOutput'
                WHEN N'statisticsTime' THEN N'#CreateExecutionEvidenceJson_StatisticsTimeOutput'
                WHEN N'planStatisticsUsage' THEN N'#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput'
                WHEN N'objectReferences' THEN N'#CreateExecutionEvidenceJson_ObjectReferencesOutput'
                WHEN N'currentStatistics' THEN N'#CreateExecutionEvidenceJson_StatisticsCurrentOutput'
                WHEN N'histogramSummaries' THEN N'#CreateExecutionEvidenceJson_HistogramSummaryOutput'
                WHEN N'histogramSteps' THEN N'#CreateExecutionEvidenceJson_HistogramStepsOutput'
                WHEN N'predicateHistogramMappings' THEN N'#CreateExecutionEvidenceJson_PredicateMappingsOutput'
                WHEN N'collectionStatus' THEN N'#CreateExecutionEvidenceJson_CollectionStatus'
                WHEN N'warnings' THEN N'#CreateExecutionEvidenceJson_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [MapCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [MapCursor];DEALLOCATE [MapCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCodeOut NOT IN ('AVAILABLE')
    BEGIN
        DECLARE @Message nvarchar(2048)=FORMATMESSAGE(N'WARNUNG USP_CreateExecutionEvidenceJson: %s - %s',@StatusCodeOut,COALESCE(@ErrorMessageOut,N'partielle Evidenz'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;
END;
GO
-- END SOURCE: Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql

-- BEGIN SOURCE: Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql
/*
===============================================================================
Objekt       : monitor.USP_ExecutionPlanAnalysis
Version      : 1.2.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Analysiert genau ein direkt übergebenes oder gezielt beschafftes
               Showplan-XML. Der direkte @PlanXml-Pfad ist eigenständig nutzbar.
Planquellen  : IMPORTED, COMPILE, LAST_ACTUAL, CURRENT_ACTUAL, QUERY_STORE.
Evidenz      : Optional bereits strukturiertes Evidence JSON oder bereits
               erfasste SET STATISTICS IO/TIME-Meldungen. Es wird kein fremdes
               SQL ausgeführt und keine Erfassungsoption aktiviert.
Datenschutz  : Parameter-/Histogrammwerte standardmäßig DERIVED_ONLY. SQL-Text
               wird nur mit @MitSqlText=1 ausgegeben. Query-Store-Hint- und
               Feedbackpayloads folgen demselben expliziten Datenschutzmodus.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml                        xml             = NULL
    , @PlanHandle                     varbinary(64)   = NULL
    , @SessionIds                     nvarchar(max)   = NULL
    , @RequestId                      int             = NULL
    , @QueryStoreDatabaseName         sysname         = NULL
    , @QueryStorePlanId               bigint          = NULL
    , @PlanQuelle                     varchar(24)      = 'AUTO'
    , @StatementId                    int             = NULL
    , @StatementQueryHash             binary(8)       = NULL
    , @StatementQueryPlanHash         binary(8)       = NULL
    , @EvidenzJson                    nvarchar(max)   = NULL
    , @StatisticsIoText               nvarchar(max)   = NULL
    , @StatisticsTimeText             nvarchar(max)   = NULL
    , @StatisticsLanguage             varchar(16)     = 'AUTO'
    , @StatistikEvidenzModus          varchar(16)     = 'PLAN_ONLY'
    , @HistogrammModus                varchar(16)     = 'NONE'
    , @MetadatenQuellenmodus          varchar(16)     = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt        bit             = 0
    , @MitPredicateHistogramMap       bit             = 1
    , @AnalyseTiefe                   varchar(16)      = 'STANDARD'
    , @WorkloadProfil                 varchar(32)      = 'AUTO'
    , @Regelsatz                      varchar(32)      = 'DEFAULT'
    , @MinSchweregrad                 varchar(16)      = 'INFO'
    , @MitThreadRuntime               bit             = 0
    , @MitSqlText                     bit             = 0
    , @EvidenzDatenschutzModus        varchar(24)      = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus     varchar(16)      = 'RAW'
    , @SensitiveDataConfirmed         bit             = 0
    , @MaxOperatoren                  int             = 50000
    , @MaxFindings                    int             = 5000
    , @MaxStatistiken                 int             = 100
    , @MaxHistogrammSchritte          int             = 20000
    , @MaxDurationSeconds             int             = 30
    , @LockTimeoutMs                  int             = 0
    , @HighImpactConfirmed            bit             = 0
    , @ResultSetArt                   varchar(16)      = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)   = NULL
    , @JsonErzeugen                   bit             = 0
    , @Json                           nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                 bit             = 1
    , @Hilfe                          bit             = 0
    , @StatusCodeOut                  varchar(40)     = NULL OUTPUT
    , @IsPartialOut                   bit             = NULL OUTPUT
    , @ErrorNumberOut                 int             = NULL OUTPUT
    , @ErrorMessageOut                nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @RequestedPlanSource varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@PlanQuelle,'AUTO'))));
    DECLARE @Depth varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseTiefe,'STANDARD'))));
    DECLARE @Profile varchar(32)=UPPER(LTRIM(RTRIM(COALESCE(@WorkloadProfil,'AUTO'))));
    DECLARE @RuleSet varchar(32)=UPPER(LTRIM(RTRIM(COALESCE(@Regelsatz,'DEFAULT'))));
    DECLARE @MinSeverity varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MinSchweregrad,'INFO'))));
    DECLARE @PrivacyMode varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@EvidenzDatenschutzModus,'DERIVED_ONLY'))));
    DECLARE @IdentifierMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@IdentifierDatenschutzModus,'RAW'))));
    DECLARE @StatisticsMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'PLAN_ONLY'))));
    DECLARE @HistogramMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))));
    DECLARE @MetadataMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MetadatenQuellenmodus,'EVIDENCE_ONLY'))));
    DECLARE @EffectivePlanSource varchar(24)=NULL;
    DECLARE @RuntimeScope varchar(32)='NONE';
    DECLARE @EffectivePlanXml xml=NULL;
    DECLARE @EvidenceForAnalysis nvarchar(max)=@EvidenzJson;
    DECLARE @Deadline datetime2(3)=DATEADD(SECOND,@MaxDurationSeconds,@Now);
    DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);
    DECLARE @EffectiveSessionId smallint=NULL;
    DECLARE @EffectiveRequestId int=@RequestId;
    DECLARE @ServerMajorVersion int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExecutionPlanAnalysis';
        PRINT N'Genau eine Planquelle: @PlanXml, @PlanHandle, genau ein Wert in @SessionIds oder @QueryStoreDatabaseName+@QueryStorePlanId.';
        PRINT N'Der direkte @PlanXml-Pfad benötigt weder Plan Cache noch Query Store. Es wird niemals übergebenes SQL ausgeführt.';
        PRINT N'@PlanQuelle gilt für @PlanHandle: AUTO|COMPILE|LAST_ACTUAL. AUTO fällt kontrolliert auf COMPILE zurück.';
        PRINT N'Optional: @EvidenzJson oder bereits erfasste @StatisticsIoText/@StatisticsTimeText.';
        PRINT N'@StatistikEvidenzModus NONE|PLAN_ONLY|USED|RELEVANT|OBJECT_ALL; @HistogrammModus NONE|SUMMARY|STEPS.';
        PRINT N'@EvidenzDatenschutzModus DERIVED_ONLY|TOKENIZED|STRUCTURE_ONLY|RAW; RAW benötigt @SensitiveDataConfirmed=1.';
        PRINT N'@MitSqlText=1 benötigt @SensitiveDataConfirmed=1, weil StatementText Literale enthalten kann.';
        PRINT N'DIAG-005 liefert planWarnings, optimizerContext, runtimeFeedback, queryStoreContext und feedbackAndVariants; Query-Store-Payloads sind standardmäßig ausgelassen.';
        PRINT N'@ResultSetArt CONSOLE|RAW|TABLE|NONE; CONSOLE liefert Findings, TABLE verwendet benannte Ziele.';
        RETURN;
    END;

    CREATE TABLE [#ExecutionPlanAnalysis_TableMap]
    (
          [ResultName] sysname NOT NULL
        , [TargetTable] sysname NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_ModuleStatus]
    (
          [ModuleName] sysname NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [PlanSource] varchar(24) NULL
        , [RuntimeCounterScope] varchar(32) NULL
        , [WorkloadProfile] varchar(32) NULL
        , [StatementCount] int NOT NULL
        , [OperatorCount] int NOT NULL
        , [FindingCount] int NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Capabilities]
    (
          [AnalysisObjectId] int NOT NULL
        , [FeatureCode] varchar(80) NOT NULL
        , [IsAvailable] bit NOT NULL
        , [AvailabilityReason] varchar(80) NOT NULL
        , [EvidenceSource] varchar(40) NOT NULL
        , [Detail] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_PlanDocuments]
    (
          [AnalysisObjectId] int NOT NULL
        , [PlanSource] varchar(24) NOT NULL
        , [RuntimeCounterScope] varchar(32) NOT NULL
        , [ShowplanVersion] nvarchar(64) NULL
        , [ShowplanBuild] nvarchar(64) NULL
        , [SourceProductVersion] nvarchar(128) NULL
        , [SourceCompatibilityLevel] smallint NULL
        , [CardinalityEstimationModelVersion] int NULL
        , [IsPlanComplete] bit NOT NULL
        , [PlanDocumentHash] varbinary(32) NULL
        , [StatementCount] int NOT NULL
        , [OperatorCount] int NOT NULL
        , [HasRuntimeCounters] bit NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Statements]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [StatementCompId] int NULL
        , [StatementType] nvarchar(128) NULL
        , [StatementText] nvarchar(max) NULL
        , [StatementQueryHash] nvarchar(130) NULL
        , [StatementQueryPlanHash] nvarchar(130) NULL
        , [StatementSubTreeCost] decimal(38,8) NULL
        , [StatementEstimatedRows] decimal(38,4) NULL
        , [OptimizationLevel] nvarchar(128) NULL
        , [EarlyAbortReason] nvarchar(256) NULL
        , [CardinalityEstimationModelVersion] int NULL
        , [CompileTimeMs] bigint NULL
        , [CompileCpuMs] bigint NULL
        , [CompileMemoryKb] bigint NULL
        , [RetrievedFromCache] bit NULL
        , [NonParallelPlanReason] nvarchar(256) NULL
        , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Operators]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [ParentNodeId] int NULL
        , [ChildOrdinal] int NULL
        , [Depth] int NULL
        , [OperatorPath] nvarchar(1000) NULL
        , [PhysicalOp] nvarchar(128) NULL
        , [LogicalOp] nvarchar(128) NULL
        , [EstimateRows] decimal(38,4) NULL
        , [EstimatedRowsRead] decimal(38,4) NULL
        , [EstimatedExecutions] decimal(38,4) NULL
        , [EstimateRebinds] decimal(38,4) NULL
        , [EstimateRewinds] decimal(38,4) NULL
        , [EstimatedCpu] decimal(38,8) NULL
        , [EstimatedIo] decimal(38,8) NULL
        , [AverageRowSize] decimal(38,4) NULL
        , [EstimatedTotalSubtreeCost] decimal(38,8) NULL
        , [Parallel] bit NULL
        , [EstimatedExecutionMode] nvarchar(60) NULL
        , [ActualExecutionMode] nvarchar(60) NULL
        , [Ordered] bit NULL
        , [ScanDirection] nvarchar(60) NULL
        , [ObjectDatabaseName] nvarchar(256) NULL
        , [ObjectSchemaName] nvarchar(256) NULL
        , [ObjectName] nvarchar(256) NULL
        , [IndexName] nvarchar(256) NULL
        , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal],[NodeId])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_OperatorThreadRuntime]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [ThreadId] int NULL
        , [BrickId] int NULL
        , [ActualRows] decimal(38,4) NULL
        , [ActualRowsRead] decimal(38,4) NULL
        , [ActualExecutions] bigint NULL
        , [ActualRebinds] bigint NULL
        , [ActualRewinds] bigint NULL
        , [ActualEndOfScans] bigint NULL
        , [ActualScans] bigint NULL
        , [ActualLogicalReads] bigint NULL
        , [ActualPhysicalReads] bigint NULL
        , [ActualReadAheads] bigint NULL
        , [ActualCpuMs] bigint NULL
        , [ActualElapsedMs] bigint NULL
        , [ActualLobLogicalReads] bigint NULL
        , [ActualLobPhysicalReads] bigint NULL
        , [IsRowsReadPaired] bit NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_OperatorRuntime]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [RuntimeCounterCount] int NOT NULL
        , [RowsReadCounterCount] int NOT NULL
        , [RowsReadCounterCoveragePercent] decimal(9,4) NULL
        , [ActualRows] decimal(38,4) NULL
        , [ActualRowsRead] decimal(38,4) NULL
        , [PairedActualRows] decimal(38,4) NULL
        , [PairedActualRowsRead] decimal(38,4) NULL
        , [ActualExecutions] bigint NULL
        , [ActualRebinds] bigint NULL
        , [ActualRewinds] bigint NULL
        , [ActualLogicalReads] bigint NULL
        , [ActualPhysicalReads] bigint NULL
        , [ActualReadAheads] bigint NULL
        , [ActualCpuMs] bigint NULL
        , [ActualElapsedMs] bigint NULL
        , [EstimatedRowsTotal] decimal(38,4) NULL
        , [ActualToEstimatedRatio] decimal(38,8) NULL
        , [CardinalityLog10Error] decimal(19,6) NULL
        , [RowsReadNotReturned] decimal(38,4) NULL
        , [RowsReadNotReturnedPercent] decimal(19,6) NULL
        , [RuntimeMetricStatus] varchar(40) NOT NULL
        , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal],[NodeId])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_AccessPaths]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [PhysicalOp] nvarchar(128) NULL
        , [LogicalOp] nvarchar(128) NULL
        , [DatabaseName] nvarchar(256) NULL
        , [SchemaName] nvarchar(256) NULL
        , [ObjectName] nvarchar(256) NULL
        , [IndexName] nvarchar(256) NULL
        , [StorageType] nvarchar(128) NULL
        , [IsLookup] bit NOT NULL
        , [Ordered] bit NULL
        , [ScanDirection] nvarchar(60) NULL
        , [EstimateRows] decimal(38,4) NULL
        , [EstimatedRowsRead] decimal(38,4) NULL
        , [ActualRows] decimal(38,4) NULL
        , [ActualRowsRead] decimal(38,4) NULL
        , [ActualExecutions] bigint NULL
        , [RowsReadNotReturned] decimal(38,4) NULL
        , [RowsReadNotReturnedPercent] decimal(19,6) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_StatisticsUsage]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatisticsUsageOrdinal] bigint NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [StatementCompId] int NULL
        , [DatabaseName] sysname NULL
        , [SchemaName] sysname NULL
        , [ObjectName] sysname NULL
        , [StatisticsName] sysname NULL
        , [LastUpdateAtCompile] datetime2(7) NULL
        , [ModificationCountAtCompile] bigint NULL
        , [SamplingPercentAtCompile] decimal(19,6) NULL
        , [CurrentLastUpdated] datetime2(7) NULL
        , [CurrentRows] bigint NULL
        , [CurrentRowsSampled] bigint NULL
        , [CurrentModificationCounter] bigint NULL
        , [CurrentSamplePercent] decimal(19,6) NULL
        , [StatisticsChangedSinceCompile] bit NULL
        , [MetadataMatchStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Parameters]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [ParameterName] nvarchar(256) NULL
        , [ParameterDataType] nvarchar(256) NULL
        , [CompiledValue] nvarchar(4000) NULL
        , [RuntimeValue] nvarchar(4000) NULL
        , [CompiledValueToken] varbinary(32) NULL
        , [RuntimeValueToken] varbinary(32) NULL
        , [CompiledValueLength] int NULL
        , [RuntimeValueLength] int NULL
        , [ValueHandlingStatus] varchar(40) NOT NULL
        , [ValueSource] varchar(40) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_ParameterEvidence]
    (
          [CandidateId] int NOT NULL
        , [SessionId] smallint NULL
        , [RequestId] int NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [StatementQueryHash] nvarchar(130) NULL
        , [StatementQueryPlanHash] nvarchar(130) NULL
        , [PlanHandle] varbinary(64) NULL
        , [QueryStoreDatabaseName] sysname NULL
        , [QueryStorePlanId] bigint NULL
        , [PlanDocumentHash] nvarchar(66) NULL
        , [EvidenceKind] varchar(24) NOT NULL
        , [ParameterName] nvarchar(256) NULL
        , [ParameterDataType] nvarchar(256) NULL
        , [CompiledValuePresent] bit NOT NULL
        , [RuntimeValuePresent] bit NOT NULL
        , [CompiledValueIsSqlNull] bit NULL
        , [RuntimeValueIsSqlNull] bit NULL
        , [CompiledValue] nvarchar(4000) NULL
        , [RuntimeValue] nvarchar(4000) NULL
        , [CompiledValueToken] nvarchar(66) NULL
        , [RuntimeValueToken] nvarchar(66) NULL
        , [CompiledValueLength] int NULL
        , [RuntimeValueLength] int NULL
        , [CompiledValueStatus] varchar(40) NOT NULL
        , [RuntimeValueStatus] varchar(40) NOT NULL
        , [ValueStatus] varchar(40) NOT NULL
        , [ValueHandlingStatus] varchar(40) NOT NULL
        , [ValueSource] varchar(40) NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [ValueCapturedAtUtc] datetime2(3) NULL
        , [IsCurrentExecution] bit NULL
        , [IsLastKnownExecution] bit NULL
        , [IsComplete] bit NOT NULL
        , [EvidenceLimit] nvarchar(1000) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_SourceContext]
    (
          [AnalysisObjectId] int NOT NULL
        , [PlanHandle] varbinary(64) NULL
        , [SourceCapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [DatabaseId] int NULL
        , [SetOptions] bigint NULL
        , [CompileUserId] int NULL
        , [PlanGenerationNum] bigint NULL
        , [CacheCreationTime] datetime NULL
        , [CacheLastExecutionTime] datetime NULL
        , [ExecutionCount] bigint NULL
        , [CacheObjectType] nvarchar(34) NULL
        , [CacheObjectClass] nvarchar(16) NULL
        , [CacheUseCounts] int NULL
        , [CacheRefCounts] int NULL
        , [CacheSizeBytes] bigint NULL
        , [CachePoolId] int NULL
        , [EvidenceLimit] nvarchar(1000) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_PlanWarnings]
    (
          [WarningOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [WarningCode] varchar(100) NOT NULL
        , [WarningCategory] varchar(40) NOT NULL
        , [Severity] varchar(16) NOT NULL
        , [EvidenceKind] varchar(40) NOT NULL
        , [EvidenceSource] varchar(40) NOT NULL
        , [PlanSource] varchar(24) NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [IsCurrent] bit NULL
        , [IsLastKnown] bit NULL
        , [IsMeasured] bit NOT NULL
        , [IsInferred] bit NOT NULL
        , [MetricName] varchar(80) NULL
        , [MetricValue] decimal(38,4) NULL
        , [MetricUnit] nvarchar(40) NULL
        , [Detail] nvarchar(2000) NOT NULL
        , [FalsePositiveGuard] nvarchar(2000) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , PRIMARY KEY ([WarningOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_OptimizerContext]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [PlanSource] varchar(24) NULL
        , [RuntimeCounterScope] varchar(32) NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [IsCurrent] bit NULL
        , [IsLastKnown] bit NULL
        , [OptimizationLevel] nvarchar(128) NULL
        , [EarlyAbortReason] nvarchar(256) NULL
        , [CardinalityEstimationModelVersion] int NULL
        , [StatementSubTreeCost] decimal(38,8) NULL
        , [StatementEstimatedRows] decimal(38,4) NULL
        , [CompileTimeMs] bigint NULL
        , [CompileCpuMs] bigint NULL
        , [CompileMemoryKb] bigint NULL
        , [RetrievedFromCache] bit NULL
        , [NonParallelPlanReason] nvarchar(256) NULL
        , [PlanDegreeOfParallelism] int NULL
        , [PlanGenerationNum] bigint NULL
        , [CacheCreationTime] datetime NULL
        , [CacheLastExecutionTime] datetime NULL
        , [CacheExecutionCount] bigint NULL
        , [CacheObjectType] nvarchar(34) NULL
        , [CacheObjectClass] nvarchar(16) NULL
        , [CacheUseCounts] int NULL
        , [CacheRefCounts] int NULL
        , [CacheSizeBytes] bigint NULL
        , [CachePoolId] int NULL
        , [SetOptions] bigint NULL
        , [CompileUserId] int NULL
        , [DatabaseId] int NULL
        , [EvidenceMeasurement] varchar(40) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [FalsePositiveGuard] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_RuntimeFeedback]
    (
          [FeedbackOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [FeedbackType] varchar(40) NOT NULL
        , [FeedbackState] nvarchar(128) NULL
        , [MetricName] varchar(80) NULL
        , [ObservedValue] decimal(38,4) NULL
        , [BaselineValue] decimal(38,4) NULL
        , [DeltaRatio] decimal(38,8) NULL
        , [MetricUnit] nvarchar(40) NULL
        , [RuntimeCounterScope] varchar(32) NULL
        , [EvidenceSource] varchar(40) NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [IsCurrent] bit NULL
        , [IsLastKnown] bit NULL
        , [IsMeasured] bit NOT NULL
        , [IsDerived] bit NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
        , PRIMARY KEY ([FeedbackOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_QueryStoreContext]
    (
          [AnalysisObjectId] int NOT NULL
        , [QueryStoreDatabaseName] sysname NULL
        , [QueryStorePlanId] bigint NULL
        , [QueryStoreQueryId] bigint NULL
        , [PlanGroupId] bigint NULL
        , [EngineVersion] nvarchar(32) NULL
        , [CompatibilityLevel] smallint NULL
        , [QueryPlanHash] binary(8) NULL
        , [IsTrivialPlan] bit NULL
        , [IsParallelPlan] bit NULL
        , [IsForcedPlan] bit NULL
        , [PlanForcingTypeDesc] nvarchar(60) NULL
        , [ForceFailureCount] bigint NULL
        , [LastForceFailureReason] int NULL
        , [LastForceFailureReasonDesc] nvarchar(128) NULL
        , [CountCompiles] bigint NULL
        , [InitialCompileStartTime] datetimeoffset(7) NULL
        , [LastCompileStartTime] datetimeoffset(7) NULL
        , [LastExecutionTime] datetimeoffset(7) NULL
        , [AvgCompileDurationUs] float NULL
        , [LastCompileDurationUs] bigint NULL
        , [ContextSettingsId] bigint NULL
        , [ObjectId] bigint NULL
        , [QueryHash] binary(8) NULL
        , [QueryParameterizationTypeDesc] nvarchar(60) NULL
        , [AvgOptimizeDurationUs] float NULL
        , [AvgCompileMemoryKb] float NULL
        , [HasCompileReplayScript] bit NULL
        , [IsOptimizedPlanForcingDisabled] bit NULL
        , [PlanType] int NULL
        , [PlanTypeDesc] nvarchar(120) NULL
        , [RuntimeExecutionCount] bigint NULL
        , [RuntimeLastExecutionTime] datetimeoffset(7) NULL
        , [AvgDurationUs] decimal(38,4) NULL
        , [AvgCpuTimeUs] decimal(38,4) NULL
        , [AvgLogicalIoReads] decimal(38,4) NULL
        , [AvgLogicalIoWrites] decimal(38,4) NULL
        , [QueryHintCount] int NOT NULL
        , [QueryHintFailureCount] bigint NOT NULL
        , [PersistedFeedbackCount] int NOT NULL
        , [VariantRelationCount] int NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [IsCurrent] bit NOT NULL
        , [IsLastKnown] bit NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_QueryStorePlanSource]
    (
          [AnalysisObjectId] int NOT NULL
        , [QueryStoreDatabaseName] sysname NOT NULL
        , [QueryStorePlanId] bigint NOT NULL
        , [QueryStoreQueryId] bigint NOT NULL
        , [PlanGroupId] bigint NULL
        , [EngineVersion] nvarchar(32) NULL
        , [CompatibilityLevel] smallint NULL
        , [QueryPlanHash] binary(8) NULL
        , [QueryPlanXml] xml NULL
        , [IsTrivialPlan] bit NULL
        , [IsParallelPlan] bit NULL
        , [IsForcedPlan] bit NULL
        , [PlanForcingTypeDesc] nvarchar(60) NULL
        , [ForceFailureCount] bigint NULL
        , [LastForceFailureReason] int NULL
        , [LastForceFailureReasonDesc] nvarchar(128) NULL
        , [CountCompiles] bigint NULL
        , [InitialCompileStartTime] datetimeoffset(7) NULL
        , [LastCompileStartTime] datetimeoffset(7) NULL
        , [LastExecutionTime] datetimeoffset(7) NULL
        , [AvgCompileDurationUs] float NULL
        , [LastCompileDurationUs] bigint NULL
        , [ContextSettingsId] bigint NULL
        , [ObjectId] bigint NULL
        , [QueryHash] binary(8) NULL
        , [QueryParameterizationTypeDesc] nvarchar(60) NULL
        , [AvgOptimizeDurationUs] float NULL
        , [AvgCompileMemoryKb] float NULL
        , [HasCompileReplayScript] bit NULL
        , [IsOptimizedPlanForcingDisabled] bit NULL
        , [PlanType] int NULL
        , [PlanTypeDesc] nvarchar(120) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_FeedbackAndVariants]
    (
          [RecordOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [AnalysisObjectId] int NOT NULL
        , [RecordType] varchar(40) NOT NULL
        , [FeatureType] varchar(60) NOT NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [QueryStorePlanId] bigint NULL
        , [QueryStoreQueryId] bigint NULL
        , [ParentQueryId] bigint NULL
        , [DispatcherPlanId] bigint NULL
        , [QueryVariantQueryId] bigint NULL
        , [QueryVariantId] int NULL
        , [FeatureState] nvarchar(128) NULL
        , [FeatureData] nvarchar(max) NULL
        , [FeatureDataToken] varbinary(32) NULL
        , [FeatureDataLength] int NULL
        , [DataHandlingStatus] varchar(40) NOT NULL
        , [EvidenceSource] varchar(40) NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [IsCurrent] bit NULL
        , [IsLastKnown] bit NULL
        , [IsMeasured] bit NOT NULL
        , [IsDerived] bit NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
        , PRIMARY KEY ([RecordOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_MemoryAndSpills]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [RecordType] varchar(24) NOT NULL
        , [SpillKind] nvarchar(128) NULL
        , [SpillLevel] int NULL
        , [SpilledDataSize] bigint NULL
        , [WritesToTempDb] bigint NULL
        , [ReadsFromTempDb] bigint NULL
        , [RequestedMemoryKb] bigint NULL
        , [GrantedMemoryKb] bigint NULL
        , [MaxUsedMemoryKb] bigint NULL
        , [GrantWaitTimeMs] bigint NULL
        , [MemoryGrantFeedbackState] nvarchar(128) NULL
        , [Detail] nvarchar(1000) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_ExecutionEvidence]
    (
          [AnalysisObjectId] int NOT NULL
        , [EvidenceType] varchar(40) NOT NULL
        , [StatementOrdinal] int NULL
        , [ScopeName] nvarchar(512) NULL
        , [MetricName] varchar(80) NOT NULL
        , [MetricValue] decimal(38,4) NULL
        , [MetricUnit] nvarchar(40) NULL
        , [EvidenceStatus] varchar(40) NOT NULL
        , [SameExecutionConfidence] varchar(40) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Findings]
    (
          [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [AnalysisObjectId] int NOT NULL
        , [FindingCode] varchar(100) NOT NULL
        , [Category] varchar(40) NOT NULL
        , [Severity] varchar(16) NOT NULL
        , [Confidence] varchar(32) NOT NULL
        , [EvidenceLevel] varchar(40) NOT NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [PhysicalOp] nvarchar(128) NULL
        , [LogicalOp] nvarchar(128) NULL
        , [MetricName] varchar(80) NULL
        , [MetricValue] decimal(38,4) NULL
        , [MetricUnit] nvarchar(40) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [ThresholdSource] varchar(80) NULL
        , [WorkloadProfile] varchar(32) NOT NULL
        , [Summary] nvarchar(1000) NOT NULL
        , [Evidence] nvarchar(2000) NOT NULL
        , [EvidenceLimit] nvarchar(2000) NOT NULL
        , [CounterEvidence] nvarchar(1000) NULL
        , [RecommendedNextCheck] nvarchar(1000) NOT NULL
        , PRIMARY KEY ([FindingOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_HistogramSummaries]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatisticsId] int NULL,[LeadingColumnName] sysname NULL
        , [HistogramSteps] int NULL,[HistogramEstimatedRows] float NULL,[MaxEqualRows] float NULL
        , [MaxRangeRows] float NULL,[MaxStepRows] float NULL,[DominantStepPercent] decimal(19,6) NULL
        , [TailStepRows] float NULL,[TailStepPercent] decimal(19,6) NULL,[CollectionStatus] varchar(40) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_HistogramSteps]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatisticsId] int NULL,[LeadingColumnName] sysname NULL
        , [StepOrdinal] int NULL,[RangeHighKey] nvarchar(4000) NULL,[RangeHighKeyToken] varbinary(32) NULL
        , [RangeRows] float NULL,[EqualRows] float NULL,[DistinctRangeRows] bigint NULL,[AverageRangeRows] float NULL
        , [IsPredicateTarget] bit NULL,[PredicateMatchCount] int NULL,[SensitiveValueStatus] varchar(40) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_PredicateHistogramMappings]
    (
          [PredicateReferenceId] bigint NULL,[StatementOrdinal] int NULL,[NodeId] int NULL
        , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ColumnName] sysname NULL
        , [StatisticsName] sysname NULL,[PredicateKind] varchar(40) NULL,[ValueSource] varchar(32) NULL
        , [MappingStatus] varchar(48) NULL,[MappingConfidence] varchar(16) NULL,[MatchedStepOrdinal] int NULL
        , [MatchesRangeHighKey] bit NULL,[IsBelowHistogram] bit NULL,[IsAboveHistogram] bit NULL
        , [SensitiveValueStatus] varchar(40) NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @RequestedPlanSource NOT IN ('AUTO','COMPILE','LAST_ACTUAL')
       OR @Depth NOT IN ('SUMMARY','STANDARD','FULL')
       OR @RuleSet<>'DEFAULT'
       OR @MinSeverity NOT IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL')
       OR @MitThreadRuntime NOT IN (0,1) OR @MitSqlText NOT IN (0,1)
       OR @PrivacyMode NOT IN ('DERIVED_ONLY','TOKENIZED','RAW','STRUCTURE_ONLY')
       OR @IdentifierMode NOT IN ('RAW','TOKENIZED','OMIT')
       OR @StatisticsMode NOT IN ('NONE','PLAN_ONLY','USED','RELEVANT','OBJECT_ALL')
       OR @HistogramMode NOT IN ('NONE','SUMMARY','STEPS')
       OR @MetadataMode NOT IN ('EVIDENCE_ONLY','CURRENT_SERVER')
       OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxOperatoren IS NULL OR @MaxOperatoren<1
       OR @MaxFindings IS NULL OR @MaxFindings<1
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @JsonErzeugen NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Modus-, Grenzwert-, Planquellen-, Ausgabe- oder Datenschutzparameter.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND NULLIF(LTRIM(RTRIM(COALESCE(@SessionIds,N''))),N'') IS NOT NULL
    BEGIN
        IF EXISTS
           (
               SELECT 1
               FROM [monitor].[TVF_ParseBigintList](@SessionIds)
               WHERE [IsValid]<>1
                  OR [NumberValue] NOT BETWEEN 1 AND 32767
           )
           OR 1<>(SELECT COUNT(*) FROM [monitor].[TVF_ParseBigintList](@SessionIds))
        BEGIN
            SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
                   @ErrorMessageOut=N'@SessionIds muss für diese Ein-Plan-Analyse genau eine gültige smallint-Session-ID enthalten.';
        END
        ELSE
        BEGIN
            SELECT @EffectiveSessionId=CONVERT(smallint,[NumberValue])
            FROM [monitor].[TVF_ParseBigintList](@SessionIds);
        END;
    END;

    DECLARE @PlanSourceGroupCount int=
          CASE WHEN @PlanXml IS NOT NULL THEN 1 ELSE 0 END
        + CASE WHEN @PlanHandle IS NOT NULL THEN 1 ELSE 0 END
        + CASE WHEN @EffectiveSessionId IS NOT NULL THEN 1 ELSE 0 END
        + CASE WHEN @QueryStoreDatabaseName IS NOT NULL OR @QueryStorePlanId IS NOT NULL THEN 1 ELSE 0 END;

    IF @StatusCodeOut='AVAILABLE' AND @PlanSourceGroupCount<>1
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Genau eine Planquelle muss angegeben werden.';
    END;
    IF @StatusCodeOut='AVAILABLE'
       AND ((@QueryStoreDatabaseName IS NULL AND @QueryStorePlanId IS NOT NULL)
         OR (@QueryStoreDatabaseName IS NOT NULL AND @QueryStorePlanId IS NULL))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Query Store benötigt @QueryStoreDatabaseName und @QueryStorePlanId gemeinsam.';
    END;
    IF @StatusCodeOut='AVAILABLE' AND @PrivacyMode='RAW' AND @SensitiveDataConfirmed<>1
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'RAW-Parameter- oder Histogrammwerte benötigen @SensitiveDataConfirmed=1.';
    END;
    IF @StatusCodeOut='AVAILABLE' AND @MitSqlText=1 AND @SensitiveDataConfirmed<>1
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'StatementText kann Literale und proprietären SQL-Text enthalten. @MitSqlText=1 benötigt @SensitiveDataConfirmed=1.';
    END;
    IF @StatusCodeOut='AVAILABLE' AND @MetadataMode='CURRENT_SERVER' AND @QuellumgebungBestaetigt<>1
    BEGIN
        SELECT @StatusCodeOut='SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'CURRENT_SERVER-Anreicherung benötigt @QuellumgebungBestaetigt=1.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|capabilities|planDocuments|statements|operatorTree|operatorRuntime|operatorThreadRuntime|accessPaths|statisticsUsage|parametersAndVariants|parameters|planWarnings|optimizerContext|runtimeFeedback|queryStoreContext|feedbackAndVariants|memoryAndSpills|executionEvidence|histogramSummaries|histogramSteps|predicateHistogramMappings|findings'
            , @MappingTable=N'#ExecutionPlanAnalysis_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCodeOut='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.';
    END;
    IF @ConsoleResultRequested=1 SET @OutputMode='NONE';

    /*
      Cachekontext wird je Aufruf genau einmal materialisiert. Ein
      USP_ShowplanAnalysis-Parent stellt seinen bereits gelesenen Kandidaten-
      Snapshot über eine lokale Temp-Tabelle bereit; ein direkter Planhandle-
      Aufruf verwendet einen gezielten Einzelread.
    */
    IF @StatusCodeOut='AVAILABLE' AND @PlanHandle IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC [sys].[sp_executesql]
                  N'INSERT [#ExecutionPlanAnalysis_SourceContext]
                    (
                          [AnalysisObjectId],[PlanHandle],[SourceCapturedAtUtc],[StatusCode]
                        , [DatabaseId],[SetOptions],[CompileUserId],[PlanGenerationNum]
                        , [CacheCreationTime],[CacheLastExecutionTime],[ExecutionCount]
                        , [CacheObjectType],[CacheObjectClass],[CacheUseCounts],[CacheRefCounts]
                        , [CacheSizeBytes],[CachePoolId],[EvidenceLimit]
                    )
                    SELECT
                          1,[PlanHandle],[SourceCapturedAtUtc],[StatusCode]
                        , [DatabaseId],[SetOptions],[CompileUserId],[PlanGenerationNum]
                        , [CacheCreationTime],[CacheLastExecutionTime],[ExecutionCount]
                        , [CacheObjectType],[CacheObjectClass],[CacheUseCounts],[CacheRefCounts]
                        , [CacheSizeBytes],[CachePoolId],[EvidenceLimit]
                    FROM [#ShowplanAnalysis_ExecutionPlanSourceContext]
                    WHERE [PlanHandle]=@RequestedPlanHandle;'
                , N'@RequestedPlanHandle varbinary(64)'
                , @RequestedPlanHandle=@PlanHandle;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>208
            BEGIN
                SET @IsPartialOut=1;
                IF @ErrorMessageOut IS NULL
                    SET @ErrorMessageOut=N'Der bereitgestellte Parent-Cachekontext konnte nicht übernommen werden.';
            END;
        END CATCH;

        IF NOT EXISTS
           (
               SELECT 1
               FROM [#ExecutionPlanAnalysis_SourceContext]
               WHERE [PlanHandle]=@PlanHandle
           )
        BEGIN TRY
            INSERT [#ExecutionPlanAnalysis_SourceContext]
            (
                  [AnalysisObjectId],[PlanHandle],[SourceCapturedAtUtc],[StatusCode]
                , [DatabaseId],[SetOptions],[CompileUserId],[PlanGenerationNum]
                , [CacheCreationTime],[CacheLastExecutionTime],[ExecutionCount]
                , [CacheObjectType],[CacheObjectClass],[CacheUseCounts],[CacheRefCounts]
                , [CacheSizeBytes],[CachePoolId],[EvidenceLimit]
            )
            SELECT
                  1,@PlanHandle,@Now
                , CASE WHEN [cp].[plan_handle] IS NULL THEN 'PLAN_CACHE_CONTEXT_UNAVAILABLE' ELSE 'AVAILABLE' END
                , [pa].[DatabaseId],[pa].[SetOptions],[pa].[CompileUserId]
                , [qs].[PlanGenerationNum],[qs].[CacheCreationTime],[qs].[CacheLastExecutionTime],[qs].[ExecutionCount]
                , [cp].[cacheobjtype],[cp].[objtype],[cp].[usecounts],[cp].[refcounts]
                , CONVERT(bigint,[cp].[size_in_bytes]),[cp].[pool_id]
                , N'Cachewerte sind eine flüchtige, nicht transaktional mit dem Plan-XML atomare Momentaufnahme.'
            FROM [sys].[dm_exec_cached_plans] AS [cp] WITH (NOLOCK)
            OUTER APPLY
            (
                SELECT
                      MAX([qs0].[plan_generation_num]) AS [PlanGenerationNum]
                    , MIN([qs0].[creation_time]) AS [CacheCreationTime]
                    , MAX([qs0].[last_execution_time]) AS [CacheLastExecutionTime]
                    , SUM([qs0].[execution_count]) AS [ExecutionCount]
                FROM [sys].[dm_exec_query_stats] AS [qs0] WITH (NOLOCK)
                WHERE [qs0].[plan_handle]=@PlanHandle
            ) AS [qs]
            OUTER APPLY
            (
                SELECT
                      MAX(CASE WHEN [a].[attribute]='dbid' THEN TRY_CONVERT(int,[a].[value]) END) AS [DatabaseId]
                    , MAX(CASE WHEN [a].[attribute]='set_options' THEN TRY_CONVERT(bigint,[a].[value]) END) AS [SetOptions]
                    , MAX(CASE WHEN [a].[attribute]='user_id' THEN TRY_CONVERT(int,[a].[value]) END) AS [CompileUserId]
                FROM [sys].[dm_exec_plan_attributes](@PlanHandle) AS [a]
            ) AS [pa]
            WHERE [cp].[plan_handle]=@PlanHandle;

            IF NOT EXISTS
               (
                   SELECT 1
                   FROM [#ExecutionPlanAnalysis_SourceContext]
                   WHERE [PlanHandle]=@PlanHandle
               )
                INSERT [#ExecutionPlanAnalysis_SourceContext]
                (
                      [AnalysisObjectId],[PlanHandle],[SourceCapturedAtUtc],[StatusCode]
                    , [EvidenceLimit]
                )
                VALUES
                (
                      1,@PlanHandle,@Now,'PLAN_CACHE_CONTEXT_UNAVAILABLE'
                    , N'Der Planhandle war beim gezielten Cachekontext-Read nicht mehr in sys.dm_exec_cached_plans sichtbar.'
                );
        END TRY
        BEGIN CATCH
            INSERT [#ExecutionPlanAnalysis_SourceContext]
            (
                  [AnalysisObjectId],[PlanHandle],[SourceCapturedAtUtc],[StatusCode]
                , [EvidenceLimit]
            )
            VALUES
            (
                  1,@PlanHandle,@Now
                , CASE WHEN ERROR_NUMBER() IN (229,371,262,297,300,916)
                       THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
                , N'Der gezielte Cachekontext-Read ist fehlgeschlagen; die Plan-XML-Analyse bleibt davon getrennt.'
            );
            SET @IsPartialOut=1;
            IF @ErrorNumberOut IS NULL
                SELECT @ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        END CATCH;
    END;

    /* Planbeschaffung. Direkt übergebenes XML bleibt vollständig standalone. */
    IF @StatusCodeOut='AVAILABLE'
    BEGIN TRY
        IF @PlanXml IS NOT NULL
        BEGIN
            SET @EffectivePlanXml=@PlanXml;
            SET @EffectivePlanSource='IMPORTED';
            SET @RuntimeScope=CASE WHEN @PlanXml.exist('//*[local-name(.)="RunTimeCountersPerThread"]')=1
                                   THEN 'IMPORTED_ACTUAL' ELSE 'NONE' END;
        END
        ELSE IF @PlanHandle IS NOT NULL
        BEGIN
            IF @RequestedPlanSource IN ('AUTO','LAST_ACTUAL')
            BEGIN
                SELECT @EffectivePlanXml=[query_plan]
                FROM [sys].[dm_exec_query_plan_stats](@PlanHandle);
                IF @EffectivePlanXml IS NOT NULL
                BEGIN
                    SET @EffectivePlanSource='LAST_ACTUAL';
                    SET @RuntimeScope='LAST_COMPLETED_EXECUTION';
                END;
            END;
            IF @EffectivePlanXml IS NULL AND @RequestedPlanSource IN ('AUTO','COMPILE')
            BEGIN
                SELECT @EffectivePlanXml=[query_plan]
                FROM [sys].[dm_exec_query_plan](@PlanHandle);
                IF @EffectivePlanXml IS NOT NULL
                BEGIN
                    SET @EffectivePlanSource='COMPILE';
                    SET @RuntimeScope='NONE';
                END;
            END;
        END
        ELSE IF @EffectiveSessionId IS NOT NULL
        BEGIN
            DECLARE @RequestCount int;
            SELECT @RequestCount=COUNT(*)
            FROM [sys].[dm_exec_query_statistics_xml](@EffectiveSessionId)
            WHERE @RequestId IS NULL OR [request_id]=@RequestId;
            IF @RequestCount>1 AND @RequestId IS NULL
                THROW 51031,N'Die Sitzung besitzt mehrere aktive Requests; @RequestId ist erforderlich.',1;
            SELECT TOP (1)
                  @EffectivePlanXml=[query_plan]
                , @EffectiveRequestId=[request_id]
            FROM [sys].[dm_exec_query_statistics_xml](@EffectiveSessionId)
            WHERE @RequestId IS NULL OR [request_id]=@RequestId
            ORDER BY [request_id];
            IF @EffectivePlanXml IS NOT NULL
            BEGIN
                SET @EffectivePlanSource='CURRENT_ACTUAL';
                SET @RuntimeScope='CURRENT_PARTIAL_EXECUTION';
            END;
        END
        ELSE
        BEGIN
            DECLARE @QueryStoreVersionColumns nvarchar(max)=CASE
                WHEN @ServerMajorVersion>=16 THEN
                    N',[p].[has_compile_replay_script],[p].[is_optimized_plan_forcing_disabled],[p].[plan_type],[p].[plan_type_desc]'
                ELSE
                    N',CONVERT(bit,NULL),CONVERT(bit,NULL),CONVERT(int,NULL),CONVERT(nvarchar(120),NULL)'
                END;
            DECLARE @QueryStoreSql nvarchar(max)=N'USE '+QUOTENAME(@QueryStoreDatabaseName)+N';
INSERT [#ExecutionPlanAnalysis_QueryStorePlanSource]
(
      [AnalysisObjectId],[QueryStoreDatabaseName],[QueryStorePlanId],[QueryStoreQueryId]
    , [PlanGroupId],[EngineVersion],[CompatibilityLevel],[QueryPlanHash],[QueryPlanXml]
    , [IsTrivialPlan],[IsParallelPlan],[IsForcedPlan],[PlanForcingTypeDesc]
    , [ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc]
    , [CountCompiles],[InitialCompileStartTime],[LastCompileStartTime],[LastExecutionTime]
    , [AvgCompileDurationUs],[LastCompileDurationUs],[ContextSettingsId],[ObjectId]
    , [QueryHash],[QueryParameterizationTypeDesc],[AvgOptimizeDurationUs],[AvgCompileMemoryKb]
    , [HasCompileReplayScript],[IsOptimizedPlanForcingDisabled],[PlanType],[PlanTypeDesc]
)
SELECT
      1,@QueryStoreDatabaseName,[p].[plan_id],[p].[query_id]
    , [p].[plan_group_id],[p].[engine_version],[p].[compatibility_level],[p].[query_plan_hash]
    , TRY_CONVERT(xml,[p].[query_plan])
    , [p].[is_trivial_plan],[p].[is_parallel_plan],[p].[is_forced_plan],[p].[plan_forcing_type_desc]
    , [p].[force_failure_count],[p].[last_force_failure_reason],[p].[last_force_failure_reason_desc]
    , [p].[count_compiles],[p].[initial_compile_start_time],[p].[last_compile_start_time],[p].[last_execution_time]
    , [p].[avg_compile_duration],[p].[last_compile_duration],[q].[context_settings_id],[q].[object_id]
    , [q].[query_hash],[q].[query_parameterization_type_desc],[q].[avg_optimize_duration],[q].[avg_compile_memory_kb]'
    +@QueryStoreVersionColumns+N'
FROM [sys].[query_store_plan] AS [p] WITH (NOLOCK)
JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id]=[p].[query_id]
WHERE [p].[plan_id]=@PlanId;';
            EXEC [sys].[sp_executesql]
                  @QueryStoreSql
                , N'@PlanId bigint,@QueryStoreDatabaseName sysname'
                , @PlanId=@QueryStorePlanId
                , @QueryStoreDatabaseName=@QueryStoreDatabaseName;
            SELECT @EffectivePlanXml=[QueryPlanXml]
            FROM [#ExecutionPlanAnalysis_QueryStorePlanSource]
            WHERE [QueryStorePlanId]=@QueryStorePlanId;
            IF @EffectivePlanXml IS NOT NULL
            BEGIN
                SET @EffectivePlanSource='QUERY_STORE';
                SET @RuntimeScope='NONE';
            END;
        END;

        IF @EffectivePlanXml IS NULL
        BEGIN
            SELECT @StatusCodeOut='UNAVAILABLE_OBJECT',@IsPartialOut=1,
                   @ErrorMessageOut=N'Die angeforderte Planquelle lieferte kein Showplan-XML.';
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE
                   WHEN ERROR_NUMBER()=569 AND @PlanHandle IS NOT NULL THEN 'UNAVAILABLE_OBJECT'
                   WHEN ERROR_NUMBER() IN (229,371,262,297,300,916) THEN 'DENIED_PERMISSION'
                   ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    /*
      Eine angeforderte, aber nicht mehr verfügbare Quelle erhält eine eigene
      DIAG-003-Evidenzzeile. Dadurch bleibt PLAN_EVICTED beziehungsweise
      REQUEST_FINISHED von SQL-NULL und einem fehlenden XML-Attribut getrennt.
    */
    IF @EffectivePlanXml IS NULL
       AND @PlanSourceGroupCount=1
       AND @StatusCodeOut IN ('UNAVAILABLE_OBJECT','DENIED_PERMISSION','ERROR_HANDLED')
    BEGIN
        DECLARE @UnavailableValueStatus varchar(40)=CASE
            WHEN @StatusCodeOut='DENIED_PERMISSION' THEN 'DENIED_PERMISSION'
            WHEN @StatusCodeOut='ERROR_HANDLED' THEN 'ERROR_HANDLED'
            WHEN @EffectiveSessionId IS NOT NULL THEN 'REQUEST_FINISHED'
            WHEN @PlanHandle IS NOT NULL THEN 'PLAN_EVICTED'
            ELSE 'NOT_COLLECTED' END;
        DECLARE @AttemptedValueSource varchar(40)=CASE
            WHEN @EffectiveSessionId IS NOT NULL THEN 'LIVE_PLAN'
            WHEN @QueryStorePlanId IS NOT NULL THEN 'QUERY_STORE_PLAN'
            WHEN @PlanHandle IS NOT NULL AND @RequestedPlanSource='COMPILE' THEN 'COMPILE_PLAN'
            WHEN @PlanHandle IS NOT NULL AND @RequestedPlanSource='LAST_ACTUAL' THEN 'LAST_ACTUAL_PLAN'
            WHEN @PlanHandle IS NOT NULL THEN 'PLAN_CACHE_ATTEMPT'
            ELSE 'IMPORTED_PLAN' END;

        INSERT [#ExecutionPlanAnalysis_ParameterEvidence]
        (
              [CandidateId],[SessionId],[RequestId],[StatementOrdinal],[StatementId]
            , [StatementQueryHash],[StatementQueryPlanHash],[PlanHandle]
            , [QueryStoreDatabaseName],[QueryStorePlanId],[PlanDocumentHash]
            , [EvidenceKind],[ParameterName],[ParameterDataType]
            , [CompiledValuePresent],[RuntimeValuePresent]
            , [CompiledValueIsSqlNull],[RuntimeValueIsSqlNull]
            , [CompiledValue],[RuntimeValue],[CompiledValueToken],[RuntimeValueToken]
            , [CompiledValueLength],[RuntimeValueLength]
            , [CompiledValueStatus],[RuntimeValueStatus],[ValueStatus]
            , [ValueHandlingStatus],[ValueSource]
            , [SourceObservedAtUtc],[ValueCapturedAtUtc]
            , [IsCurrentExecution],[IsLastKnownExecution],[IsComplete],[EvidenceLimit]
        )
        VALUES
        (
              1,@EffectiveSessionId,@EffectiveRequestId,NULL,NULL,NULL,NULL,@PlanHandle
            , @QueryStoreDatabaseName,@QueryStorePlanId,NULL
            , 'SOURCE_STATUS',NULL,NULL,0,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
            , 'NOT_COLLECTED','NOT_COLLECTED',@UnavailableValueStatus
            , CASE @PrivacyMode WHEN 'RAW' THEN 'AVAILABLE_RAW'
                   WHEN 'TOKENIZED' THEN 'TOKENIZED_CAPTURE_LOCAL'
                   WHEN 'STRUCTURE_ONLY' THEN 'OMITTED_STRUCTURE_ONLY'
                   ELSE 'OMITTED_DERIVED_ONLY' END
            , @AttemptedValueSource,@Now,NULL
            , CASE WHEN @EffectiveSessionId IS NOT NULL THEN CONVERT(bit,1) END
            , CASE WHEN @RequestedPlanSource='LAST_ACTUAL' THEN CONVERT(bit,1)
                   WHEN @RequestedPlanSource='COMPILE' OR @EffectiveSessionId IS NOT NULL THEN CONVERT(bit,0) END
            , 0
            , CASE @UnavailableValueStatus
                  WHEN 'PLAN_EVICTED' THEN N'Das angeforderte Planhandle war beim gezielten Abruf nicht mehr auflösbar.'
                  WHEN 'REQUEST_FINISHED' THEN N'Der angeforderte Request lieferte beim gezielten Live-Plan-Abruf keine laufende Ausführung mehr.'
                  WHEN 'DENIED_PERMISSION' THEN N'Die Planquelle war mit dem aktuellen Sicherheitskontext nicht lesbar.'
                  ELSE N'Die angeforderte Planquelle lieferte keine auswertbare Parameterevidenz.' END
        );
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND (@Depth='FULL' OR @StatisticsMode IN ('RELEVANT','OBJECT_ALL') OR @HistogramMode='STEPS')
    BEGIN
        IF @HighImpactConfirmed<>1
        BEGIN
            SELECT @StatusCodeOut='HIGH_IMPACT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
                   @ErrorMessageOut=N'Der angeforderte FULL-/breite Statistik-/Histogrammpfad benötigt @HighImpactConfirmed=1.';
        END;
        ELSE IF EXISTS
        (
            SELECT 1 FROM [sys].[procedures] AS [p] WITH (NOLOCK)
            JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
            WHERE [s].[name]=N'monitor' AND [p].[name]=N'InternalCheckAnalysisPath'
        )
        BEGIN
            DECLARE @GateStatus varchar(40),@GateMessage nvarchar(2048);
            EXEC [sys].[sp_executesql]
                  N'EXEC [monitor].[InternalCheckAnalysisPath]
                          @AnalysisClass=''SHOWPLAN_XML_DEEP'',
                          @HighImpactConfirmed=@Confirmed,
                          @StatusCode=@Status OUTPUT,
                          @ErrorMessage=@Message OUTPUT;'
                , N'@Confirmed bit,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT'
                , @Confirmed=@HighImpactConfirmed,@Status=@GateStatus OUTPUT,@Message=@GateMessage OUTPUT;
            IF @GateStatus<>'AVAILABLE'
                SELECT @StatusCodeOut=@GateStatus,@IsPartialOut=1,@ErrorMessageOut=@GateMessage;
        END;
    END;

    /* AUTO-Profil: explizite lokale Zuordnung, sonst BALANCED. */
    IF @StatusCodeOut='AVAILABLE'
    BEGIN
        IF @Profile='AUTO'
        BEGIN
            SELECT TOP (1) @Profile=[a].[ProfileCode]
            FROM [monitor].[PlanAnalysisProfileAssignment] AS [a] WITH (NOLOCK)
            JOIN [monitor].[PlanAnalysisProfile] AS [p] WITH (NOLOCK)
              ON [p].[ProfileCode]=[a].[ProfileCode] AND [p].[IsEnabled]=1
            WHERE [a].[IsEnabled]=1
              AND (@StatementId IS NULL OR [a].[StatementId] IS NULL OR [a].[StatementId]=@StatementId)
              AND (@StatementQueryHash IS NULL OR [a].[QueryHash] IS NULL OR [a].[QueryHash]=@StatementQueryHash)
              AND ([a].[QueryStoreQueryId] IS NULL)
              AND ([a].[DatabaseNamePattern] IS NULL OR @QueryStoreDatabaseName LIKE [a].[DatabaseNamePattern])
            ORDER BY [a].[Priority],[a].[AssignmentId];
            SET @Profile=COALESCE(@Profile,'BALANCED');
        END;
        IF NOT EXISTS(SELECT 1 FROM [monitor].[PlanAnalysisProfile] WHERE [ProfileCode]=@Profile AND [IsEnabled]=1)
            SET @Profile='BALANCED';
    END;

    /* Public contract: Jede externe oder intern erzeugte Evidenz wird vor der
       Analyse erneut normalisiert. Dadurch gelten Datenschutz-, Shape- und
       Versionsregeln auch für direkt übergebenes @EvidenzJson. */
    IF @StatusCodeOut='AVAILABLE'
    BEGIN
        DECLARE @EvidenceStatus varchar(40),@EvidencePartial bit,@EvidenceError int,@EvidenceMessage nvarchar(2048);
        EXEC [monitor].[USP_CreateExecutionEvidenceJson]
              @PlanXml=@EffectivePlanXml
            , @StatisticsIoText=@StatisticsIoText
            , @StatisticsTimeText=@StatisticsTimeText
            , @StatisticsLanguage=@StatisticsLanguage
            , @StatistikEvidenzModus=@StatisticsMode
            , @HistogrammModus=@HistogramMode
            , @MetadatenQuellenmodus=@MetadataMode
            , @QuellumgebungBestaetigt=@QuellumgebungBestaetigt
            , @EvidenzDatenschutzModus=@PrivacyMode
            , @IdentifierDatenschutzModus='RAW'
            , @SensitiveDataConfirmed=@SensitiveDataConfirmed
            , @MitPredicateHistogramMap=@MitPredicateHistogramMap
            , @StatementId=@StatementId
            , @ExistingEvidenceJson=@EvidenceForAnalysis
            , @MaxStatistiken=@MaxStatistiken
            , @MaxHistogrammSchritte=@MaxHistogrammSchritte
            , @LockTimeoutMs=@LockTimeoutMs
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @RawTextHandling='HASH_ONLY'
            , @StrictValidation=1
            , @ResultSetArt='NONE'
            , @JsonErzeugen=1
            , @Json=@EvidenceForAnalysis OUTPUT
            , @PrintMeldungen=0
            , @StatusCodeOut=@EvidenceStatus OUTPUT
            , @IsPartialOut=@EvidencePartial OUTPUT
            , @ErrorNumberOut=@EvidenceError OUTPUT
            , @ErrorMessageOut=@EvidenceMessage OUTPUT;
        IF COALESCE(@EvidencePartial,0)=1 OR @EvidenceStatus='PARTIAL'
            SET @IsPartialOut=1;
        IF @EvidenceStatus NOT IN ('AVAILABLE','PARTIAL')
        BEGIN
            SET @IsPartialOut=1;
            IF @ErrorMessageOut IS NULL SET @ErrorMessageOut=CONCAT(N'Evidenzanreicherung: ',COALESCE(@EvidenceMessage,@EvidenceStatus));
        END;
    END;

    IF @StatusCodeOut='AVAILABLE'
    BEGIN
        DECLARE @AnalyzerStatus varchar(40),@AnalyzerPartial bit,@AnalyzerError int,@AnalyzerMessage nvarchar(2048);
        EXEC [monitor].[InternalAnalyzeExecutionPlan]
              @AnalysisObjectId=1
            , @PlanXml=@EffectivePlanXml
            , @PlanSource=@EffectivePlanSource
            , @RuntimeCounterScope=@RuntimeScope
            , @WorkloadProfile=@Profile
            , @MinSeverity=@MinSeverity
            , @EvidenceJson=@EvidenceForAnalysis
            , @MitThreadRuntime=@MitThreadRuntime
            , @EvidenzDatenschutzModus=@PrivacyMode
            , @IdentifierDatenschutzModus=@IdentifierMode
            , @SourceObservedAtUtc=@Now
            , @ParameterEvidenceSessionId=@EffectiveSessionId
            , @ParameterEvidenceRequestId=@EffectiveRequestId
            , @PlanHandle=@PlanHandle
            , @QueryStoreDatabaseName=@QueryStoreDatabaseName
            , @QueryStorePlanId=@QueryStorePlanId
            , @StatusCodeOut=@AnalyzerStatus OUTPUT
            , @IsPartialOut=@AnalyzerPartial OUTPUT
            , @ErrorNumberOut=@AnalyzerError OUTPUT
            , @ErrorMessageOut=@AnalyzerMessage OUTPUT;
        IF COALESCE(@AnalyzerPartial,0)=1 OR @AnalyzerStatus='PARTIAL'
            SET @IsPartialOut=1;
        IF @AnalyzerStatus<>'AVAILABLE'
        BEGIN
            SET @StatusCodeOut=@AnalyzerStatus;
            SET @IsPartialOut=1;
            SET @ErrorNumberOut=@AnalyzerError;
            SET @ErrorMessageOut=@AnalyzerMessage;
        END;
    END;

    /*
      DIAG-005: Query Store wird nur für die ausdrücklich angeforderte
      Query-Store-Planquelle gelesen. Plan, Query und Runtimeaggregation werden
      gezielt materialisiert; 2022+-Feedback, Hints und Varianten bleiben
      versionsadaptiv hinter Dynamic SQL. Querytexte werden nicht gelesen.
    */
    IF EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_QueryStorePlanSource])
    BEGIN
        BEGIN TRY
            DECLARE @QueryStoreContextSql nvarchar(max)=N'USE '+QUOTENAME(@QueryStoreDatabaseName)+N';
INSERT [#ExecutionPlanAnalysis_QueryStoreContext]
(
      [AnalysisObjectId],[QueryStoreDatabaseName],[QueryStorePlanId],[QueryStoreQueryId]
    , [PlanGroupId],[EngineVersion],[CompatibilityLevel],[QueryPlanHash]
    , [IsTrivialPlan],[IsParallelPlan],[IsForcedPlan],[PlanForcingTypeDesc]
    , [ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc]
    , [CountCompiles],[InitialCompileStartTime],[LastCompileStartTime],[LastExecutionTime]
    , [AvgCompileDurationUs],[LastCompileDurationUs],[ContextSettingsId],[ObjectId]
    , [QueryHash],[QueryParameterizationTypeDesc],[AvgOptimizeDurationUs],[AvgCompileMemoryKb]
    , [HasCompileReplayScript],[IsOptimizedPlanForcingDisabled],[PlanType],[PlanTypeDesc]
    , [RuntimeExecutionCount],[RuntimeLastExecutionTime],[AvgDurationUs],[AvgCpuTimeUs]
    , [AvgLogicalIoReads],[AvgLogicalIoWrites]
    , [QueryHintCount],[QueryHintFailureCount],[PersistedFeedbackCount],[VariantRelationCount]
    , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[StatusCode],[EvidenceLimit]
)
SELECT
      [s].[AnalysisObjectId],[s].[QueryStoreDatabaseName],[s].[QueryStorePlanId],[s].[QueryStoreQueryId]
    , [s].[PlanGroupId],[s].[EngineVersion],[s].[CompatibilityLevel],[s].[QueryPlanHash]
    , [s].[IsTrivialPlan],[s].[IsParallelPlan],[s].[IsForcedPlan],[s].[PlanForcingTypeDesc]
    , [s].[ForceFailureCount],[s].[LastForceFailureReason],[s].[LastForceFailureReasonDesc]
    , [s].[CountCompiles],[s].[InitialCompileStartTime],[s].[LastCompileStartTime],[s].[LastExecutionTime]
    , [s].[AvgCompileDurationUs],[s].[LastCompileDurationUs],[s].[ContextSettingsId],[s].[ObjectId]
    , [s].[QueryHash],[s].[QueryParameterizationTypeDesc],[s].[AvgOptimizeDurationUs],[s].[AvgCompileMemoryKb]
    , [s].[HasCompileReplayScript],[s].[IsOptimizedPlanForcingDisabled],[s].[PlanType],[s].[PlanTypeDesc]
    , [r].[RuntimeExecutionCount],[r].[RuntimeLastExecutionTime]
    , [r].[AvgDurationUs],[r].[AvgCpuTimeUs],[r].[AvgLogicalIoReads],[r].[AvgLogicalIoWrites]
    , 0,0,0,0,@ObservedAtUtc,0,1,''AVAILABLE''
    , N''Query-Store-Werte sind persistierte Aggregate über das vorhandene Erfassungsfenster; Intervalle, Bereinigungen und Capture-Modus begrenzen Vergleiche.''
FROM [#ExecutionPlanAnalysis_QueryStorePlanSource] AS [s]
OUTER APPLY
(
    SELECT
          [RuntimeExecutionCount]=SUM(CONVERT(bigint,[rs].[count_executions]))
        , [RuntimeLastExecutionTime]=MAX([rs].[last_execution_time])
        , [AvgDurationUs]=CONVERT(decimal(38,4),
              SUM(CONVERT(decimal(38,8),[rs].[avg_duration])*CONVERT(decimal(38,8),[rs].[count_executions]))
              /NULLIF(SUM(CONVERT(decimal(38,8),[rs].[count_executions])),0))
        , [AvgCpuTimeUs]=CONVERT(decimal(38,4),
              SUM(CONVERT(decimal(38,8),[rs].[avg_cpu_time])*CONVERT(decimal(38,8),[rs].[count_executions]))
              /NULLIF(SUM(CONVERT(decimal(38,8),[rs].[count_executions])),0))
        , [AvgLogicalIoReads]=CONVERT(decimal(38,4),
              SUM(CONVERT(decimal(38,8),[rs].[avg_logical_io_reads])*CONVERT(decimal(38,8),[rs].[count_executions]))
              /NULLIF(SUM(CONVERT(decimal(38,8),[rs].[count_executions])),0))
        , [AvgLogicalIoWrites]=CONVERT(decimal(38,4),
              SUM(CONVERT(decimal(38,8),[rs].[avg_logical_io_writes])*CONVERT(decimal(38,8),[rs].[count_executions]))
              /NULLIF(SUM(CONVERT(decimal(38,8),[rs].[count_executions])),0))
    FROM [sys].[query_store_runtime_stats] AS [rs] WITH (NOLOCK)
    WHERE [rs].[plan_id]=[s].[QueryStorePlanId]
) AS [r];';
            EXEC [sys].[sp_executesql]
                  @QueryStoreContextSql
                , N'@ObservedAtUtc datetime2(3)'
                , @ObservedAtUtc=@Now;

            INSERT [#ExecutionPlanAnalysis_RuntimeFeedback]
            (
                  [AnalysisObjectId],[FeedbackType],[FeedbackState],[MetricName]
                , [ObservedValue],[BaselineValue],[MetricUnit],[RuntimeCounterScope]
                , [EvidenceSource],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown]
                , [IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
            )
            SELECT
                  [AnalysisObjectId],'QUERY_STORE_AGGREGATE','PERSISTED_AGGREGATE'
                , 'AVERAGE_DURATION_US',[AvgDurationUs],[AvgCpuTimeUs],'microseconds'
                , 'QUERY_STORE_AGGREGATE','QUERY_STORE_RUNTIME_STATS',[SourceObservedAtUtc]
                , 0,1,1,1,'AVAILABLE'
                , N'Die gewichteten Query-Store-Mittelwerte stammen aus dem sichtbaren Retentionfenster und sind keine einzelne aktuelle Ausführung.'
            FROM [#ExecutionPlanAnalysis_QueryStoreContext]
            WHERE [RuntimeExecutionCount] IS NOT NULL;

            IF @ServerMajorVersion>=16
            BEGIN
                DECLARE @QueryStoreFeedbackSql nvarchar(max)=N'USE '+QUOTENAME(@QueryStoreDatabaseName)+N';
INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
(
      [AnalysisObjectId],[RecordType],[FeatureType],[QueryStorePlanId],[QueryStoreQueryId]
    , [FeatureState],[FeatureData],[FeatureDataToken],[FeatureDataLength],[DataHandlingStatus]
    , [EvidenceSource],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
    , [StatusCode],[EvidenceLimit]
)
SELECT
      1,''PERSISTED_FEEDBACK'',CONVERT(varchar(60),[f].[feature_desc])
    , [f].[plan_id],[s].[QueryStoreQueryId],CONVERT(nvarchar(128),[f].[state_desc])
    , CASE WHEN @EvidencePrivacyMode=''RAW'' AND @Confirmed=1 THEN [f].[feedback_data] END
    , CASE WHEN @EvidencePrivacyMode=''TOKENIZED'' AND [f].[feedback_data] IS NOT NULL
           THEN HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),[f].[feedback_data])) END
    , DATALENGTH([f].[feedback_data])/2
    , CASE WHEN @EvidencePrivacyMode=''RAW'' AND @Confirmed=1 THEN ''AVAILABLE_RAW''
           WHEN @EvidencePrivacyMode=''TOKENIZED'' THEN ''TOKENIZED''
           WHEN @EvidencePrivacyMode=''STRUCTURE_ONLY'' THEN ''OMITTED_STRUCTURE_ONLY''
           ELSE ''OMITTED_DERIVED_ONLY'' END
    , ''QUERY_STORE_PLAN_FEEDBACK'',@ObservedAtUtc,0,1,1,0,''AVAILABLE''
    , N''Persistiertes Feedback ist versions-, zustands- und bereinigungsabhängig; FeatureData kann sensitive oder proprietäre Inhalte enthalten.''
FROM [sys].[query_store_plan_feedback] AS [f] WITH (NOLOCK)
JOIN [#ExecutionPlanAnalysis_QueryStorePlanSource] AS [s]
  ON [s].[QueryStorePlanId]=[f].[plan_id];

INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
(
      [AnalysisObjectId],[RecordType],[FeatureType],[QueryStorePlanId],[QueryStoreQueryId]
    , [ParentQueryId],[DispatcherPlanId],[QueryVariantQueryId]
    , [FeatureState],[DataHandlingStatus],[EvidenceSource],[SourceObservedAtUtc]
    , [IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
)
SELECT
      1,''QUERY_VARIANT_RELATION'',''PARAMETER_SENSITIVE_PLAN''
    , [s].[QueryStorePlanId],[s].[QueryStoreQueryId]
    , [v].[parent_query_id],[v].[dispatcher_plan_id],[v].[query_variant_query_id]
    , N''PERSISTED_RELATION'',''NO_SENSITIVE_PAYLOAD'',''QUERY_STORE_QUERY_VARIANT'',@ObservedAtUtc
    , 0,1,1,0,''AVAILABLE''
    , N''Die Relation belegt Dispatcher und Queryvariante, nicht deren relative Leistungsqualität.''
FROM [sys].[query_store_query_variant] AS [v] WITH (NOLOCK)
JOIN [#ExecutionPlanAnalysis_QueryStorePlanSource] AS [s]
  ON [s].[QueryStoreQueryId] IN ([v].[query_variant_query_id],[v].[parent_query_id]);

INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
(
      [AnalysisObjectId],[RecordType],[FeatureType],[QueryStorePlanId],[QueryStoreQueryId]
    , [FeatureState],[FeatureData],[FeatureDataToken],[FeatureDataLength],[DataHandlingStatus]
    , [EvidenceSource],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
    , [StatusCode],[EvidenceLimit]
)
SELECT
      1,''QUERY_STORE_HINT'',''QUERY_STORE_HINT'',[s].[QueryStorePlanId],[h].[query_id]
    , CASE WHEN COALESCE([h].[query_hint_failure_count],0)>0 THEN N''FAILURE_RECORDED'' ELSE N''CONFIGURED'' END
    , CASE WHEN @EvidencePrivacyMode=''RAW'' AND @Confirmed=1 THEN [h].[query_hint_text] END
    , CASE WHEN @EvidencePrivacyMode=''TOKENIZED'' AND [h].[query_hint_text] IS NOT NULL
           THEN HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),[h].[query_hint_text])) END
    , DATALENGTH([h].[query_hint_text])/2
    , CASE WHEN @EvidencePrivacyMode=''RAW'' AND @Confirmed=1 THEN ''AVAILABLE_RAW''
           WHEN @EvidencePrivacyMode=''TOKENIZED'' THEN ''TOKENIZED''
           WHEN @EvidencePrivacyMode=''STRUCTURE_ONLY'' THEN ''OMITTED_STRUCTURE_ONLY''
           ELSE ''OMITTED_DERIVED_ONLY'' END
    , ''QUERY_STORE_QUERY_HINTS'',@ObservedAtUtc,0,1,1,0,''AVAILABLE''
    , N''Hinttext kann sensitive oder proprietäre Inhalte enthalten; die Zeile bewertet weder Korrektheit noch Nutzen des Hints.''
FROM [sys].[query_store_query_hints] AS [h] WITH (NOLOCK)
JOIN [#ExecutionPlanAnalysis_QueryStorePlanSource] AS [s]
  ON [s].[QueryStoreQueryId]=[h].[query_id];

UPDATE [q]
SET [QueryHintFailureCount]=COALESCE([h].[QueryHintFailureCount],0)
FROM [#ExecutionPlanAnalysis_QueryStoreContext] AS [q]
OUTER APPLY
(
    SELECT
          [QueryHintFailureCount]=SUM(CONVERT(bigint,[h0].[query_hint_failure_count]))
    FROM [sys].[query_store_query_hints] AS [h0] WITH (NOLOCK)
    JOIN [#ExecutionPlanAnalysis_QueryStorePlanSource] AS [s0]
      ON [s0].[QueryStoreQueryId]=[h0].[query_id]
    WHERE [s0].[AnalysisObjectId]=[q].[AnalysisObjectId]
) AS [h];';
                EXEC [sys].[sp_executesql]
                      @QueryStoreFeedbackSql
                    , N'@ObservedAtUtc datetime2(3),@EvidencePrivacyMode varchar(24),@Confirmed bit'
                    , @ObservedAtUtc=@Now,@EvidencePrivacyMode=@PrivacyMode,@Confirmed=@SensitiveDataConfirmed;

                IF NOT EXISTS
                   (
                       SELECT 1
                       FROM [#ExecutionPlanAnalysis_FeedbackAndVariants]
                       WHERE [EvidenceSource] IN
                             ('QUERY_STORE_PLAN_FEEDBACK','QUERY_STORE_QUERY_HINTS','QUERY_STORE_QUERY_VARIANT')
                   )
                    INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
                    (
                          [AnalysisObjectId],[RecordType],[FeatureType],[FeatureState]
                        , [DataHandlingStatus],[EvidenceSource],[SourceObservedAtUtc]
                        , [IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
                        , [StatusCode],[EvidenceLimit]
                    )
                    VALUES
                    (
                          1,'SOURCE_STATUS','QUERY_STORE_OPTIONAL_CONTEXT',N'NO_PERSISTED_ROWS'
                        , 'NO_SENSITIVE_PAYLOAD','QUERY_STORE_OPTIONAL_SOURCES',@Now
                        , 0,1,1,0,'AVAILABLE'
                        , N'Die unterstützten Query-Store-Feedback-, Hint- und Variantenquellen wurden gezielt gelesen und enthielten für den Plan keine Zeile.'
                    );
            END;
            ELSE
                INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
                (
                      [AnalysisObjectId],[RecordType],[FeatureType],[FeatureState]
                    , [DataHandlingStatus],[EvidenceSource],[SourceObservedAtUtc]
                    , [IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
                    , [StatusCode],[EvidenceLimit]
                )
                VALUES
                (
                      1,'SOURCE_STATUS','QUERY_STORE_OPTIONAL_CONTEXT',N'REQUIRES_SQL_SERVER_2022'
                    , 'NO_SENSITIVE_PAYLOAD','QUERY_STORE_OPTIONAL_SOURCES',@Now
                    , 0,1,0,0,'NOT_APPLICABLE'
                    , N'Persistiertes Planfeedback, Query-Store-Hints und Queryvarianten werden erst auf SQL Server 2022 oder neuer gelesen.'
                );

            UPDATE [q]
            SET
                  [QueryHintCount]=[a].[QueryHintCount]
                , [PersistedFeedbackCount]=[a].[PersistedFeedbackCount]
                , [VariantRelationCount]=[a].[VariantRelationCount]
            FROM [#ExecutionPlanAnalysis_QueryStoreContext] AS [q]
            CROSS APPLY
            (
                SELECT
                      [QueryHintCount]=COUNT(CASE WHEN [RecordType]='QUERY_STORE_HINT' THEN 1 END)
                    , [PersistedFeedbackCount]=COUNT(CASE WHEN [RecordType]='PERSISTED_FEEDBACK' THEN 1 END)
                    , [VariantRelationCount]=COUNT(CASE WHEN [RecordType]='QUERY_VARIANT_RELATION' THEN 1 END)
                FROM [#ExecutionPlanAnalysis_FeedbackAndVariants]
                WHERE [AnalysisObjectId]=[q].[AnalysisObjectId]
            ) AS [a];
        END TRY
        BEGIN CATCH
            SET @IsPartialOut=1;
            UPDATE [#ExecutionPlanAnalysis_QueryStoreContext]
            SET
                  [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,371,262,297,300,916)
                                    THEN 'DENIED_PERMISSION' ELSE 'PARTIAL' END
                , [EvidenceLimit]=N'Der Plan blieb analysierbar; zusätzliche Query-Store-Kontextquellen waren nicht vollständig verfügbar.'
            WHERE [AnalysisObjectId]=1;

            INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
            (
                  [AnalysisObjectId],[RecordType],[FeatureType],[FeatureState]
                , [DataHandlingStatus],[EvidenceSource],[SourceObservedAtUtc]
                , [IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived]
                , [StatusCode],[EvidenceLimit]
            )
            VALUES
            (
                  1,'SOURCE_STATUS','QUERY_STORE_OPTIONAL_CONTEXT',N'READ_FAILED'
                , 'NO_SENSITIVE_PAYLOAD','QUERY_STORE_OPTIONAL_SOURCES',@Now
                , 0,1,0,0
                , CASE WHEN ERROR_NUMBER() IN (229,371,262,297,300,916)
                       THEN 'DENIED_PERMISSION' ELSE 'PARTIAL' END
                , N'Der Plan blieb analysierbar; mindestens eine zusätzliche Query-Store-Kontextquelle war nicht vollständig verfügbar.'
            );

            INSERT [#ExecutionPlanAnalysis_QueryStoreContext]
            (
                  [AnalysisObjectId],[QueryStoreDatabaseName],[QueryStorePlanId]
                , [QueryHintCount],[QueryHintFailureCount],[PersistedFeedbackCount],[VariantRelationCount]
                , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[StatusCode],[EvidenceLimit]
            )
            SELECT
                  1,@QueryStoreDatabaseName,@QueryStorePlanId,0,0,0,0,@Now,0,1
                , CASE WHEN ERROR_NUMBER() IN (229,371,262,297,300,916) THEN 'DENIED_PERMISSION' ELSE 'PARTIAL' END
                , N'Der Plan blieb analysierbar; zusätzliche Query-Store-Kontextquellen waren nicht vollständig verfügbar.'
            WHERE NOT EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_QueryStoreContext]);
            IF @ErrorNumberOut IS NULL
                SELECT @ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        END CATCH;
    END
    ELSE
        INSERT [#ExecutionPlanAnalysis_QueryStoreContext]
        (
              [AnalysisObjectId],[QueryStoreDatabaseName],[QueryStorePlanId]
            , [QueryHintCount],[QueryHintFailureCount],[PersistedFeedbackCount],[VariantRelationCount]
            , [SourceObservedAtUtc],[IsCurrent],[IsLastKnown],[StatusCode],[EvidenceLimit]
        )
        VALUES
        (
              1,@QueryStoreDatabaseName,@QueryStorePlanId,0,0,0,0,@Now,0
            , CASE WHEN @QueryStorePlanId IS NOT NULL THEN 1 ELSE 0 END
            , CASE WHEN @QueryStorePlanId IS NULL THEN 'NOT_APPLICABLE'
                   WHEN @StatusCodeOut='DENIED_PERMISSION' THEN 'DENIED_PERMISSION'
                   ELSE 'NOT_COLLECTED' END
            , CASE WHEN @QueryStorePlanId IS NULL
                   THEN N'Für diese Planquelle wurde kein Query-Store-Plan angefordert.'
                   ELSE N'Die angeforderte Query-Store-Quelle lieferte keinen materialisierbaren Kontext.' END
        );

    /* Jede kanonische DIAG-005-Ausgabe besitzt auch bei Quellfehlern eine
       eindeutige Statuszeile. */
    IF NOT EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_PlanWarnings])
        INSERT [#ExecutionPlanAnalysis_PlanWarnings]
        (
              [AnalysisObjectId],[WarningCode],[WarningCategory],[Severity],[EvidenceKind]
            , [EvidenceSource],[PlanSource],[SourceObservedAtUtc],[IsMeasured],[IsInferred]
            , [Detail],[FalsePositiveGuard],[StatusCode]
        )
        VALUES
        (
              1,'SOURCE_UNAVAILABLE','SOURCE_STATUS','INFO','SOURCE_STATUS'
            , 'PLAN_SOURCE',@EffectivePlanSource,@Now,0,0
            , N'Die Planquelle lieferte keine normalisierbare Warnungsevidenz.'
            , N'Ein Quellfehler darf nicht als warnungsfreier Plan interpretiert werden.'
            , CASE WHEN @StatusCodeOut='DENIED_PERMISSION' THEN 'DENIED_PERMISSION' ELSE 'NOT_COLLECTED' END
        );
    IF NOT EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_OptimizerContext])
        INSERT [#ExecutionPlanAnalysis_OptimizerContext]
        (
              [AnalysisObjectId],[PlanSource],[RuntimeCounterScope],[SourceObservedAtUtc]
            , [EvidenceMeasurement],[StatusCode],[FalsePositiveGuard]
        )
        VALUES
        (
              1,@EffectivePlanSource,@RuntimeScope,@Now,'NOT_MEASURED'
            , CASE WHEN @StatusCodeOut='DENIED_PERMISSION' THEN 'DENIED_PERMISSION' ELSE 'NOT_COLLECTED' END
            , N'Fehlender Optimizerkontext darf nicht als optimale oder triviale Kompilierung interpretiert werden.'
        );
    IF NOT EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_RuntimeFeedback])
        INSERT [#ExecutionPlanAnalysis_RuntimeFeedback]
        (
              [AnalysisObjectId],[FeedbackType],[RuntimeCounterScope],[EvidenceSource]
            , [SourceObservedAtUtc],[IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
        )
        VALUES
        (
              1,'SOURCE_STATUS',@RuntimeScope,'PLAN_SOURCE',@Now,0,0
            , CASE WHEN @StatusCodeOut='DENIED_PERMISSION' THEN 'DENIED_PERMISSION' ELSE 'NOT_COLLECTED' END
            , N'Ohne Runtimeevidenz werden keine Laufzeitaussagen abgeleitet.'
        );
    IF NOT EXISTS(SELECT 1 FROM [#ExecutionPlanAnalysis_FeedbackAndVariants])
        INSERT [#ExecutionPlanAnalysis_FeedbackAndVariants]
        (
              [AnalysisObjectId],[RecordType],[FeatureType],[FeatureState]
            , [DataHandlingStatus],[EvidenceSource],[SourceObservedAtUtc]
            , [IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
        )
        VALUES
        (
              1,'SOURCE_STATUS','SOURCE_UNAVAILABLE',N'NOT_COLLECTED'
            , 'NO_SENSITIVE_PAYLOAD','PLAN_SOURCE',@Now,0,0
            , CASE WHEN @StatusCodeOut='DENIED_PERMISSION' THEN 'DENIED_PERMISSION' ELSE 'NOT_COLLECTED' END
            , N'Ohne Plan- oder Katalogevidenz werden keine Feedback- oder Variantenmerkmale behauptet.'
        );

    /* Current-Statistics- und Histogrammteile aus normalisierter Evidenz ergänzen. */
    IF @EvidenceForAnalysis IS NOT NULL AND ISJSON(@EvidenceForAnalysis)=1
    BEGIN
        ;WITH [CurrentStats] AS
        (
            SELECT *
            FROM OPENJSON(@EvidenceForAnalysis,N'$.statistics.currentSnapshot')
            WITH
            (
                  [DatabaseName] sysname N'$.databaseName'
                , [SchemaName] sysname N'$.schemaName'
                , [ObjectName] sysname N'$.objectName'
                , [StatisticsName] sysname N'$.statisticsName'
                , [LastUpdated] datetime2(7) N'$.lastUpdated'
                , [Rows] bigint N'$.rows'
                , [RowsSampled] bigint N'$.rowsSampled'
                , [ModificationCounter] bigint N'$.modificationCounter'
                , [SamplePercent] decimal(19,6) N'$.samplePercent'
            )
        )
        UPDATE [u]
        SET
              [u].[CurrentLastUpdated]=[c].[LastUpdated]
            , [u].[CurrentRows]=[c].[Rows]
            , [u].[CurrentRowsSampled]=[c].[RowsSampled]
            , [u].[CurrentModificationCounter]=[c].[ModificationCounter]
            , [u].[CurrentSamplePercent]=[c].[SamplePercent]
            , [u].[StatisticsChangedSinceCompile]=CONVERT(bit,CASE
                  WHEN [u].[LastUpdateAtCompile] IS NULL OR [c].[LastUpdated] IS NULL THEN 0
                  WHEN [u].[LastUpdateAtCompile]<>[c].[LastUpdated] THEN 1 ELSE 0 END)
            , [u].[MetadataMatchStatus]='AVAILABLE'
        FROM [#ExecutionPlanAnalysis_StatisticsUsage] AS [u]
        JOIN [CurrentStats] AS [c]
          ON [c].[DatabaseName]=[u].[DatabaseName]
         AND [c].[SchemaName]=[u].[SchemaName]
         AND [c].[ObjectName]=[u].[ObjectName]
         AND [c].[StatisticsName]=[u].[StatisticsName];

        INSERT [#ExecutionPlanAnalysis_HistogramSummaries]
        SELECT *
        FROM OPENJSON(@EvidenceForAnalysis,N'$.statistics.histogramSummaries')
        WITH
        (
              [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
            , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
            , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
            , [HistogramSteps] int N'$.histogramSteps',[HistogramEstimatedRows] float N'$.histogramEstimatedRows'
            , [MaxEqualRows] float N'$.maxEqualRows',[MaxRangeRows] float N'$.maxRangeRows'
            , [MaxStepRows] float N'$.maxStepRows',[DominantStepPercent] decimal(19,6) N'$.dominantStepPercent'
            , [TailStepRows] float N'$.tailStepRows',[TailStepPercent] decimal(19,6) N'$.tailStepPercent'
            , [CollectionStatus] varchar(40) N'$.collectionStatus'
        );
        INSERT [#ExecutionPlanAnalysis_HistogramSteps]
        SELECT *
        FROM OPENJSON(@EvidenceForAnalysis,N'$.statistics.histogramSteps')
        WITH
        (
              [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
            , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
            , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
            , [StepOrdinal] int N'$.stepOrdinal',[RangeHighKey] nvarchar(4000) N'$.rangeHighKey'
            , [RangeHighKeyToken] varbinary(32) N'$.rangeHighKeyToken'
            , [RangeRows] float N'$.rangeRows',[EqualRows] float N'$.equalRows'
            , [DistinctRangeRows] bigint N'$.distinctRangeRows',[AverageRangeRows] float N'$.averageRangeRows'
            , [IsPredicateTarget] bit N'$.isPredicateTarget',[PredicateMatchCount] int N'$.predicateMatchCount'
            , [SensitiveValueStatus] varchar(40) N'$.sensitiveValueStatus'
        );
        INSERT [#ExecutionPlanAnalysis_PredicateHistogramMappings]
        SELECT *
        FROM OPENJSON(@EvidenceForAnalysis,N'$.predicateHistogramMappings')
        WITH
        (
              [PredicateReferenceId] bigint N'$.predicateReferenceId',[StatementOrdinal] int N'$.statementOrdinal'
            , [NodeId] int N'$.nodeId',[DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
            , [ObjectName] sysname N'$.objectName',[ColumnName] sysname N'$.columnName'
            , [StatisticsName] sysname N'$.statisticsName',[PredicateKind] varchar(40) N'$.predicateKind'
            , [ValueSource] varchar(32) N'$.valueSource',[MappingStatus] varchar(48) N'$.mappingStatus'
            , [MappingConfidence] varchar(16) N'$.mappingConfidence',[MatchedStepOrdinal] int N'$.matchedStepOrdinal'
            , [MatchesRangeHighKey] bit N'$.matchesRangeHighKey',[IsBelowHistogram] bit N'$.isBelowHistogram'
            , [IsAboveHistogram] bit N'$.isAboveHistogram',[SensitiveValueStatus] varchar(40) N'$.sensitiveValueStatus'
        );
    END;

    IF @StatementId IS NOT NULL
    BEGIN
        DELETE FROM [#ExecutionPlanAnalysis_PlanWarnings]
        WHERE [StatementOrdinal] IS NOT NULL AND ([StatementId]<>@StatementId OR [StatementId] IS NULL);
        DELETE FROM [#ExecutionPlanAnalysis_OptimizerContext]
        WHERE [StatementOrdinal] IS NOT NULL AND ([StatementId]<>@StatementId OR [StatementId] IS NULL);
        DELETE FROM [#ExecutionPlanAnalysis_RuntimeFeedback]
        WHERE [StatementOrdinal] IS NOT NULL AND ([StatementId]<>@StatementId OR [StatementId] IS NULL);
        DELETE FROM [#ExecutionPlanAnalysis_FeedbackAndVariants]
        WHERE [StatementOrdinal] IS NOT NULL AND ([StatementId]<>@StatementId OR [StatementId] IS NULL);
        DELETE FROM [#ExecutionPlanAnalysis_Findings] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_ExecutionEvidence] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementId]=@StatementId);
        DELETE FROM [#ExecutionPlanAnalysis_MemoryAndSpills] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_Parameters] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_ParameterEvidence]
        WHERE [EvidenceKind]='PARAMETER'
          AND ([StatementId]<>@StatementId OR [StatementId] IS NULL);
        DELETE FROM [#ExecutionPlanAnalysis_StatisticsUsage] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_AccessPaths] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_Operators] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
    END;

    IF @StatementQueryHash IS NOT NULL
    BEGIN
        DECLARE @QueryHashText nvarchar(130)=CONVERT(nvarchar(130),@StatementQueryHash,1);
        DELETE FROM [#ExecutionPlanAnalysis_PlanWarnings] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OptimizerContext] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_RuntimeFeedback] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_FeedbackAndVariants] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Findings] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_MemoryAndSpills] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Parameters] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_ParameterEvidence]
        WHERE [EvidenceKind]='PARAMETER'
          AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_StatisticsUsage] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_AccessPaths] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Operators] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]<>@QueryHashText OR [StatementQueryHash] IS NULL;
    END;

    IF @StatementQueryPlanHash IS NOT NULL
    BEGIN
        DECLARE @QueryPlanHashText nvarchar(130)=CONVERT(nvarchar(130),@StatementQueryPlanHash,1);
        DELETE FROM [#ExecutionPlanAnalysis_PlanWarnings] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OptimizerContext] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_RuntimeFeedback] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_FeedbackAndVariants] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Findings] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_MemoryAndSpills] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Parameters] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_ParameterEvidence]
        WHERE [EvidenceKind]='PARAMETER'
          AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_StatisticsUsage] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_AccessPaths] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Operators] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]<>@QueryPlanHashText OR [StatementQueryPlanHash] IS NULL;
    END;

    IF @MitSqlText=0 UPDATE [#ExecutionPlanAnalysis_Statements] SET [StatementText]=NULL;

    /* Sensitive Histogrammwerte nochmals am öffentlichen Ausgaberand sichern.
       Der Evidence-Generator hat sie bereits normalisiert; diese Projektion ist
       bewusst Defense in Depth für spätere interne Integrationspfade. */
    IF @PrivacyMode<>'RAW'
        UPDATE [#ExecutionPlanAnalysis_HistogramSteps] SET [RangeHighKey]=NULL;
    IF @PrivacyMode<>'TOKENIZED'
        UPDATE [#ExecutionPlanAnalysis_HistogramSteps] SET [RangeHighKeyToken]=NULL;

    /* Histogramm- und Predicate-Identifier passieren unabhängig vom Modus
       immer diese Ausgaberandprojektion. Die fachliche Korrelation ist zu
       diesem Zeitpunkt abgeschlossen. */
    UPDATE [#ExecutionPlanAnalysis_HistogramSummaries]
    SET [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) END,
        [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) END,
        [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) END,
        [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) END,
        [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[LeadingColumnName])),1)) END;
    UPDATE [#ExecutionPlanAnalysis_HistogramSteps]
    SET [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) END,
        [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) END,
        [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) END,
        [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) END,
        [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[LeadingColumnName])),1)) END;
    UPDATE [#ExecutionPlanAnalysis_PredicateHistogramMappings]
    SET [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) END,
        [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) END,
        [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) END,
        [ColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [ColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ColumnName])),1)) END,
        [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) END;

    /* Weitere Identifikatoren erst nach fachlicher Korrelation schützen. */
    IF @IdentifierMode IN ('TOKENIZED','OMIT')
    BEGIN
        UPDATE [#ExecutionPlanAnalysis_Operators]
        SET [ObjectDatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectDatabaseName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectDatabaseName])),1) END,
            [ObjectSchemaName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectSchemaName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectSchemaName])),1) END,
            [ObjectName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1) END,
            [IndexName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [IndexName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[IndexName])),1) END;
        UPDATE [#ExecutionPlanAnalysis_AccessPaths]
        SET [DatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [DatabaseName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1) END,
            [SchemaName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [SchemaName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1) END,
            [ObjectName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1) END,
            [IndexName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [IndexName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[IndexName])),1) END;
        UPDATE [#ExecutionPlanAnalysis_StatisticsUsage]
        SET [DatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [DatabaseName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) END,
            [SchemaName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [SchemaName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) END,
            [ObjectName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) END,
            [StatisticsName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [StatisticsName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) END;
        UPDATE [#ExecutionPlanAnalysis_Parameters]
        SET [ParameterName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ParameterName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ParameterName])),1) END;
        UPDATE [#ExecutionPlanAnalysis_ParameterEvidence]
        SET [ParameterName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ParameterName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ParameterName])),1) END,
            [QueryStoreDatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [QueryStoreDatabaseName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[QueryStoreDatabaseName])),1)) END;
        UPDATE [#ExecutionPlanAnalysis_QueryStoreContext]
        SET [QueryStoreDatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [QueryStoreDatabaseName] IS NOT NULL
            THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[QueryStoreDatabaseName])),1)) END;
    END;

    IF (SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Operators])>@MaxOperatoren
    BEGIN
        CREATE TABLE [#ExecutionPlanAnalysis_RetainedOperators]
        (
              [AnalysisObjectId] int NOT NULL
            , [StatementOrdinal] int NOT NULL
            , [NodeId] int NOT NULL
            , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal],[NodeId])
        );
        INSERT [#ExecutionPlanAnalysis_RetainedOperators]([AnalysisObjectId],[StatementOrdinal],[NodeId])
        SELECT TOP (@MaxOperatoren) [AnalysisObjectId],[StatementOrdinal],[NodeId]
        FROM [#ExecutionPlanAnalysis_Operators]
        ORDER BY [StatementOrdinal],[NodeId];

        DELETE [o]
        FROM [#ExecutionPlanAnalysis_Operators] AS [o]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[o].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[o].[StatementOrdinal]
              AND [k].[NodeId]=[o].[NodeId]
        );
        DELETE [r]
        FROM [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[r].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[r].[StatementOrdinal]
              AND [k].[NodeId]=[r].[NodeId]
        );
        DELETE [r]
        FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] AS [r]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[r].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[r].[StatementOrdinal]
              AND [k].[NodeId]=[r].[NodeId]
        );
        DELETE [a]
        FROM [#ExecutionPlanAnalysis_AccessPaths] AS [a]
        WHERE [a].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[a].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[a].[StatementOrdinal]
              AND [k].[NodeId]=[a].[NodeId]
        );
        DELETE [m]
        FROM [#ExecutionPlanAnalysis_MemoryAndSpills] AS [m]
        WHERE [m].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[m].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[m].[StatementOrdinal]
              AND [k].[NodeId]=[m].[NodeId]
        );
        DELETE [f]
        FROM [#ExecutionPlanAnalysis_Findings] AS [f]
        WHERE [f].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[f].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[f].[StatementOrdinal]
              AND [k].[NodeId]=[f].[NodeId]
        );
        DELETE [w]
        FROM [#ExecutionPlanAnalysis_PlanWarnings] AS [w]
        WHERE [w].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[w].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[w].[StatementOrdinal]
              AND [k].[NodeId]=[w].[NodeId]
        );
        DELETE [r]
        FROM [#ExecutionPlanAnalysis_RuntimeFeedback] AS [r]
        WHERE [r].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[r].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[r].[StatementOrdinal]
              AND [k].[NodeId]=[r].[NodeId]
        );
        DELETE [v]
        FROM [#ExecutionPlanAnalysis_FeedbackAndVariants] AS [v]
        WHERE [v].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[v].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[v].[StatementOrdinal]
              AND [k].[NodeId]=[v].[NodeId]
        );
        SET @IsPartialOut=1;
        IF @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END;
    IF (SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Findings])>@MaxFindings
    BEGIN
        DELETE [f]
        FROM [#ExecutionPlanAnalysis_Findings] AS [f]
        WHERE [f].[FindingOrdinal] NOT IN
        (
            SELECT TOP (@MaxFindings) [FindingOrdinal]
            FROM [#ExecutionPlanAnalysis_Findings]
            ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,
                     [FindingOrdinal]
        );
        SET @IsPartialOut=1;
        IF @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END;
    IF SYSUTCDATETIME()>@Deadline
    BEGIN
        SET @IsPartialOut=1;
        IF @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
        IF @ErrorMessageOut IS NULL SET @ErrorMessageOut=N'Das kooperative Zeitbudget wurde während der Verarbeitung überschritten.';
    END;

    INSERT [#ExecutionPlanAnalysis_ModuleStatus]
    SELECT N'USP_ExecutionPlanAnalysis',@Now,@StatusCodeOut,@IsPartialOut,@EffectivePlanSource,@RuntimeScope,@Profile,
           (SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Statements]),(SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Operators]),(SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Findings]),
           @ErrorNumberOut,@ErrorMessageOut;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'ExecutionPlanAnalysis' [resultName],3 [schemaVersion],@Now [generatedAtUtc],@StatusCodeOut [statusCode],@IsPartialOut [isPartial],@EffectivePlanSource [planSource],@RuntimeScope [runtimeCounterScope],@Profile [workloadProfile],@PrivacyMode [evidencePrivacyMode],@IdentifierMode [identifierPrivacyMode] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @CapabilitiesJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Capabilities] ORDER BY [FeatureCode] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @PlanJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_PlanDocuments] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @StatementsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Statements] ORDER BY [StatementOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @OperatorsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Operators] ORDER BY [StatementOrdinal],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RuntimeJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_OperatorRuntime] ORDER BY [StatementOrdinal],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ThreadsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] ORDER BY [StatementOrdinal],[NodeId],[ThreadId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @AccessJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_AccessPaths] ORDER BY [StatementOrdinal],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @StatsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_StatisticsUsage] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ParametersJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Parameters] ORDER BY [StatementOrdinal],[ParameterName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ParameterEvidenceJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_ParameterEvidence] ORDER BY [CandidateId],[StatementOrdinal],[EvidenceKind],[ParameterName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @PlanWarningsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_PlanWarnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @OptimizerContextJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_OptimizerContext] ORDER BY [StatementOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RuntimeFeedbackJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_RuntimeFeedback] ORDER BY [FeedbackOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @QueryStoreContextJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_QueryStoreContext] ORDER BY [QueryStorePlanId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FeedbackAndVariantsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_FeedbackAndVariants] ORDER BY [RecordOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @MemoryJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_MemoryAndSpills] ORDER BY [StatementOrdinal],[NodeId],[RecordType] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @EvidenceJsonOut nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_ExecutionEvidence] ORDER BY [StatementOrdinal],[EvidenceType],[MetricName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramSummaryJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_HistogramSummaries] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramStepsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_HistogramSteps] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @MappingsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_PredicateHistogramMappings] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FindingsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"capabilities":',COALESCE(@CapabilitiesJson,N'[]'),N',"planDocuments":',COALESCE(@PlanJson,N'[]'),N',"statements":',COALESCE(@StatementsJson,N'[]'),N',"operatorTree":',COALESCE(@OperatorsJson,N'[]'),N',"operatorRuntime":',COALESCE(@RuntimeJson,N'[]'),N',"operatorThreadRuntime":',COALESCE(@ThreadsJson,N'[]'),N',"accessPaths":',COALESCE(@AccessJson,N'[]'),N',"statisticsUsage":',COALESCE(@StatsJson,N'[]'),N',"parametersAndVariants":',COALESCE(@ParametersJson,N'[]'),N',"parameters":',COALESCE(@ParameterEvidenceJson,N'[]'),N',"planWarnings":',COALESCE(@PlanWarningsJson,N'[]'),N',"optimizerContext":',COALESCE(@OptimizerContextJson,N'[]'),N',"runtimeFeedback":',COALESCE(@RuntimeFeedbackJson,N'[]'),N',"queryStoreContext":',COALESCE(@QueryStoreContextJson,N'[]'),N',"feedbackAndVariants":',COALESCE(@FeedbackAndVariantsJson,N'[]'),N',"memoryAndSpills":',COALESCE(@MemoryJson,N'[]'),N',"executionEvidence":',COALESCE(@EvidenceJsonOut,N'[]'),N',"histogramSummaries":',COALESCE(@HistogramSummaryJson,N'[]'),N',"histogramSteps":',COALESCE(@HistogramStepsJson,N'[]'),N',"predicateHistogramMappings":',COALESCE(@MappingsJson,N'[]'),N',"findings":',COALESCE(@FindingsJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#ExecutionPlanAnalysis_ModuleStatus];
        SELECT * FROM [#ExecutionPlanAnalysis_Capabilities] ORDER BY [FeatureCode];
        SELECT * FROM [#ExecutionPlanAnalysis_PlanDocuments];
        SELECT * FROM [#ExecutionPlanAnalysis_Statements] ORDER BY [StatementOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_Operators] ORDER BY [StatementOrdinal],[NodeId];
        SELECT * FROM [#ExecutionPlanAnalysis_OperatorRuntime] ORDER BY [StatementOrdinal],[NodeId];
        SELECT * FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] ORDER BY [StatementOrdinal],[NodeId],[ThreadId];
        SELECT * FROM [#ExecutionPlanAnalysis_AccessPaths] ORDER BY [StatementOrdinal],[NodeId];
        SELECT * FROM [#ExecutionPlanAnalysis_StatisticsUsage] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_Parameters] ORDER BY [StatementOrdinal],[ParameterName];
        SELECT * FROM [#ExecutionPlanAnalysis_ParameterEvidence] ORDER BY [CandidateId],[StatementOrdinal],[EvidenceKind],[ParameterName];
        SELECT * FROM [#ExecutionPlanAnalysis_PlanWarnings] ORDER BY [WarningOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_OptimizerContext] ORDER BY [StatementOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_RuntimeFeedback] ORDER BY [FeedbackOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_QueryStoreContext] ORDER BY [QueryStorePlanId];
        SELECT * FROM [#ExecutionPlanAnalysis_FeedbackAndVariants] ORDER BY [RecordOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_MemoryAndSpills] ORDER BY [StatementOrdinal],[NodeId],[RecordType];
        SELECT * FROM [#ExecutionPlanAnalysis_ExecutionEvidence] ORDER BY [StatementOrdinal],[EvidenceType],[MetricName];
        SELECT * FROM [#ExecutionPlanAnalysis_HistogramSummaries];
        SELECT * FROM [#ExecutionPlanAnalysis_HistogramSteps];
        SELECT * FROM [#ExecutionPlanAnalysis_PredicateHistogramMappings];
        SELECT * FROM [#ExecutionPlanAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[FindingOrdinal];
    END;

    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExecutionPlanAnalysis_Findings'
            , @ResultLabel=N'Execution Plan Finding'
            , @EmptyMessage=N'Keine Findings im gewählten Scope'
            , @StatusCode=@StatusCodeOut
            , @StatusMessage=@ErrorMessageOut;

    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [OutputCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable] FROM [#ExecutionPlanAnalysis_TableMap] ORDER BY [ResultName];
        OPEN [OutputCursor];
        FETCH NEXT FROM [OutputCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'moduleStatus' THEN N'#ExecutionPlanAnalysis_ModuleStatus'
                WHEN N'capabilities' THEN N'#ExecutionPlanAnalysis_Capabilities'
                WHEN N'planDocuments' THEN N'#ExecutionPlanAnalysis_PlanDocuments'
                WHEN N'statements' THEN N'#ExecutionPlanAnalysis_Statements'
                WHEN N'operatorTree' THEN N'#ExecutionPlanAnalysis_Operators'
                WHEN N'operatorRuntime' THEN N'#ExecutionPlanAnalysis_OperatorRuntime'
                WHEN N'operatorThreadRuntime' THEN N'#ExecutionPlanAnalysis_OperatorThreadRuntime'
                WHEN N'accessPaths' THEN N'#ExecutionPlanAnalysis_AccessPaths'
                WHEN N'statisticsUsage' THEN N'#ExecutionPlanAnalysis_StatisticsUsage'
                WHEN N'parametersAndVariants' THEN N'#ExecutionPlanAnalysis_Parameters'
                WHEN N'parameters' THEN N'#ExecutionPlanAnalysis_ParameterEvidence'
                WHEN N'planWarnings' THEN N'#ExecutionPlanAnalysis_PlanWarnings'
                WHEN N'optimizerContext' THEN N'#ExecutionPlanAnalysis_OptimizerContext'
                WHEN N'runtimeFeedback' THEN N'#ExecutionPlanAnalysis_RuntimeFeedback'
                WHEN N'queryStoreContext' THEN N'#ExecutionPlanAnalysis_QueryStoreContext'
                WHEN N'feedbackAndVariants' THEN N'#ExecutionPlanAnalysis_FeedbackAndVariants'
                WHEN N'memoryAndSpills' THEN N'#ExecutionPlanAnalysis_MemoryAndSpills'
                WHEN N'executionEvidence' THEN N'#ExecutionPlanAnalysis_ExecutionEvidence'
                WHEN N'histogramSummaries' THEN N'#ExecutionPlanAnalysis_HistogramSummaries'
                WHEN N'histogramSteps' THEN N'#ExecutionPlanAnalysis_HistogramSteps'
                WHEN N'predicateHistogramMappings' THEN N'#ExecutionPlanAnalysis_PredicateHistogramMappings'
                WHEN N'findings' THEN N'#ExecutionPlanAnalysis_Findings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [OutputCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [OutputCursor];DEALLOCATE [OutputCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCodeOut NOT IN ('AVAILABLE')
    BEGIN
        DECLARE @Message nvarchar(2048)=FORMATMESSAGE(N'WARNUNG USP_ExecutionPlanAnalysis: %s - %s',@StatusCodeOut,COALESCE(@ErrorMessageOut,N'partielle Analyse'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;
END;
GO
-- END SOURCE: Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql
