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

-- Normalisierte Triage; kostenintensive optionale Module bleiben aus
DECLARE @DiagnosticFindingsJson nvarchar(max);
EXEC [monitor].[USP_DiagnosticFindings]
      @DatabaseNames=N''
    , @MitSchemaDesign=0
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
