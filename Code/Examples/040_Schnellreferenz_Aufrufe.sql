USE [DeineDatenbank];
GO

-- Hilfe
EXEC [monitor].[USP_CurrentOverview] @Hilfe=1;
-- Aktuelle Übersicht, Console
EXEC [monitor].[USP_CurrentOverview] @MaxZeilen=100,@ResultSetArt='console';
-- Zwei Datenbanken exakt
EXEC [monitor].[USP_ObjectInventory] @DatabaseNames=N'[DeineDatenbank]|[BeispielDatenbankB]',@AnalyseModus='VOLL',@MaxZeilen=200;
-- Query Store aller zum Pattern passenden Datenbanken, globales Top 100
EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=NULL,@QueryStoreDatabaseNamePattern=N'like:Database_%',@MaxDatenbanken=16,@MaxZeilen=100;
-- Memory Grants einschließlich Resource Governor
EXEC [monitor].[USP_CurrentMemoryGrants] @NurWartende=0,@MaxZeilen=100,@ResultSetArt='CONSOLE';

-- Integritätsevidenz der aktuellen Datenbank; führt kein DBCC und keine Reparatur aus
EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'',@MitPageDetails=0,@MaxZeilen=100;

-- Performance Counter mit echtem Fünf-Sekunden-Intervall für unterstützte Raten
EXEC [monitor].[USP_PerformanceCounters] @SampleSeconds=5,@MaxZeilen=100;

-- Begrenzte Statistikverteilung eines generischen Zielscopes; CATALOG_DEEP erforderlich
EXEC [monitor].[USP_StatisticsDistributionAnalysis]
      @DatabaseNames=N'[DeineDatenbank]'
    , @SchemaNames=N'dbo'
    , @AnalyseModus='GEZIELT'
    , @MaxVerteilungsStatistiken=25
    , @MaxZeilen=100;

-- Leichtgewichtige Nutzungsinventur; liest keine Locations, Credentials, Payloads oder Definitionen
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames=N''
    , @NurErkannteFeatures=1
    , @MaxZeilen=100;

-- In-Memory OLTP: Basisevidenz; teure Hashketten bleiben standardmäßig aus
EXEC [monitor].[USP_InMemoryOltpAnalysis]
      @DatabaseNames=N''
    , @MitHashIndexStats=0
    , @MaxZeilen=100;

-- Temporal Tables: nur Katalog-, Retention-, Kapazitäts- und Indexmetadaten; keine History-Zeilen
EXEC [monitor].[USP_TemporalAnalysis]
      @DatabaseNames=N''
    , @HistorySizeWarnMb=10240
    , @MaxZeilen=100;

-- Service Broker: nur Kataloge und aggregierte Laufzeitmetadaten; keine Queue-Nutzdaten
EXEC [monitor].[USP_ServiceBrokerAnalysis]
      @DatabaseNames=N''
    , @TransmissionAgeWarnMinutes=60
    , @MaxZeilen=100;

-- Full-Text: Kataloge und aggregierte Laufzeitevidenz; keine Inhalte, Crawl-Logs oder DDL
EXEC [monitor].[USP_FullTextAnalysis]
      @DatabaseNames=N''
    , @PopulationAgeWarnMinutes=60
    , @QueryableFragmentWarn=30
    , @MaxZeilen=100;

-- Change Tracking, CDC und lokale Replikation; ohne echten Consumer-Wasserstand kein CT-Verlusturteil
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames=N''
    , @CdcLatencyWarnSeconds=300
    , @ReplicationPendingCommandWarn=10000
    , @MaxZeilen=100;

-- Verschluesselungslebenszyklus; keine Schluessel-, Medien- oder Kontoinhalte
EXEC [monitor].[USP_EncryptionAnalysis]
      @DatabaseNames=N'[DeineDatenbank]'
    , @ExpliziteBackupverschluesselungErwartet=0
    , @NurProblematisch=1
    , @MaxZeilen=100;

-- Wartungsoperationen read-only; ohne Jobfilter werden Jobkataloge nicht gelesen
EXEC [monitor].[USP_MaintenanceOperations]
      @DatabaseNames=N'[DeineDatenbank]'
    , @JobNames=NULL
    , @NurProblematisch=1
    , @MaxZeilen=100;

-- Normalisierte Triage; kostenintensive optionale Module bleiben aus
DECLARE @DiagnosticFindingsJson nvarchar(max);
EXEC [monitor].[USP_DiagnosticFindings]
      @DatabaseNames=N''
    , @MitSchemaDesign=0
    , @MitStatistikverteilung=0
    , @MitIQP=0
    , @MitContention=0
    , @MaxZeilen=100
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@DiagnosticFindingsJson OUTPUT;
SELECT @DiagnosticFindingsJson AS [Json];


-- BEGIN STATEMENT-KONTEXT-BEISPIELE
-- Default: lesbare CONSOLE-Ausgabe mit exaktem Statement, Modul und Offset-/Zeileninformation
EXEC [monitor].[USP_CurrentRequests];

-- Vollständiger Batch-/Modultext und ursprünglicher Input Buffer; 0 = keine Textkürzung
EXEC [monitor].[USP_CurrentRequests]
      @GesamtenSqlTextEinbeziehen = 1
    , @InputBufferEinbeziehen = 1
    , @MaxSqlTextZeichen = 0;

-- Maschinenlesbares RAW
EXEC [monitor].[USP_CurrentRequests]
      @ResultSetArt = 'raw';

-- JSON-only mit benannten Arrays
DECLARE @CurrentRequestsJson nvarchar(max);
EXEC [monitor].[USP_CurrentRequests]
      @ResultSetArt = 'none'
    , @JsonErzeugen = 1
    , @Json = @CurrentRequestsJson OUTPUT;
SELECT @CurrentRequestsJson AS [Json];
-- END STATEMENT-KONTEXT-BEISPIELE
