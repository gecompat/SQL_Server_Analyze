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
