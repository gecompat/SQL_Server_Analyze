USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 120_ExecutionPlanAnalysis_Runtime_Contract.sql
Zweck        : Prüft die eigenständige Plananalyse ausschließlich mit einem
               synthetischen Plan-XML und synthetischer Ausführungsevidenz.
Datenschutz  : Keine realen SQL-, Objekt-, Parameter- oder Histogrammwerte.
===============================================================================
*/
SET NOCOUNT ON;

DECLARE @Plan xml=N'
<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.600" Build="17.0.1000.1">
  <BatchSequence><Batch><Statements>
    <StmtSimple StatementId="1" StatementCompId="1" StatementType="SELECT" StatementText="SELECT ExampleColumn FROM ExampleSchema.ExampleObject" StatementSubTreeCost="1.0" StatementEstRows="10" StatementOptmLevel="FULL" QueryHash="0x0101010101010101" QueryPlanHash="0x1111111111111111">
      <QueryPlan CardinalityEstimationModelVersion="170" CompileTime="2" CompileCPU="2" CompileMemory="128">
        <MemoryGrantInfo RequestedMemory="20480" GrantedMemory="20480" MaxUsedMemory="1024" GrantWaitTime="0" />
        <OptimizerStatsUsage><StatisticsInfo Database="[ExampleDatabase]" Schema="[ExampleSchema]" Table="[ExampleObject]" Statistics="[ExampleStatistics]" LastUpdate="2026-01-01T00:00:00" ModificationCount="0" SamplingPercent="100" /></OptimizerStatsUsage>
        <RelOp NodeId="0" PhysicalOp="Select" LogicalOp="Select" EstimateRows="10" EstimatedTotalSubtreeCost="1.0">
          <OutputList><ColumnReference Database="[ExampleDatabase]" Schema="[ExampleSchema]" Table="[ExampleObject]" Column="[ExampleColumn]" /></OutputList>
          <Select>
            <RelOp NodeId="1" PhysicalOp="Index Seek" LogicalOp="Index Seek" EstimateRows="10" EstimatedRowsRead="100" EstimateExecutions="1" EstimatedTotalSubtreeCost="0.9">
              <RunTimeInformation><RunTimeCountersPerThread Thread="0" ActualRows="10" ActualRowsRead="100" ActualExecutions="1" ActualLogicalReads="8" ActualCPUms="1" ActualElapsedms="2" /></RunTimeInformation>
              <IndexScan Ordered="1" ScanDirection="FORWARD"><Object Database="[ExampleDatabase]" Schema="[ExampleSchema]" Table="[ExampleObject]" Index="[ExampleIndex]" Storage="RowStore" /></IndexScan>
            </RelOp>
          </Select>
        </RelOp>
        <ParameterList><ColumnReference Column="@ExampleParameter" ParameterDataType="int" ParameterCompiledValue="(7)" ParameterRuntimeValue="(9)" /></ParameterList>
      </QueryPlan>
    </StmtSimple>
    <StmtSimple StatementId="2" StatementCompId="2" StatementType="SELECT" StatementText="SELECT ExampleOtherColumn FROM ExampleSchema.ExampleOtherObject" StatementSubTreeCost="0.1" StatementEstRows="1" StatementOptmLevel="TRIVIAL" QueryHash="0x0202020202020202" QueryPlanHash="0x2222222222222222">
      <QueryPlan CardinalityEstimationModelVersion="170" CompileTime="1" CompileCPU="1" CompileMemory="64">
        <RelOp NodeId="0" PhysicalOp="Select" LogicalOp="Select" EstimateRows="1" EstimatedTotalSubtreeCost="0.1">
          <Select><RelOp NodeId="1" PhysicalOp="Constant Scan" LogicalOp="Constant Scan" EstimateRows="1" EstimatedTotalSubtreeCost="0.0"><RunTimeInformation><RunTimeCountersPerThread Thread="0" ActualRows="1" ActualExecutions="1" /></RunTimeInformation><ConstantScan /></RelOp></Select>
        </RelOp>
      </QueryPlan>
    </StmtSimple>
  </Statements></Batch></BatchSequence>
</ShowPlanXML>';

DECLARE @AnalysisJson nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml=@Plan
    , @WorkloadProfil='BALANCED'
    , @MitThreadRuntime=1
    , @MitSqlText=0
    , @EvidenzDatenschutzModus='DERIVED_ONLY'
    , @IdentifierDatenschutzModus='RAW'
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@AnalysisJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@Error OUTPUT
    , @ErrorMessageOut=@Message OUTPUT;

IF @Status NOT IN ('AVAILABLE','PARTIAL') OR ISJSON(@AnalysisJson)<>1
    THROW 53600,N'Die eigenständige Plananalyse lieferte keinen gültigen Vertrag.',1;
IF (SELECT COUNT(*) FROM OPENJSON(@AnalysisJson,N'$.statements'))<>2
    THROW 53601,N'Der Mehrstatementplan wurde nicht statementgenau zerlegt.',1;
IF NOT EXISTS
(
    SELECT 1
    FROM OPENJSON(@AnalysisJson,N'$.statements')
    WITH
    (
          [StatementOrdinal] int N'$.StatementOrdinal'
        , [StatementType] nvarchar(128) N'$.StatementType'
        , [StatementQueryHash] nvarchar(130) N'$.StatementQueryHash'
        , [StatementSubTreeCost] decimal(38,8) N'$.StatementSubTreeCost'
        , [OptimizationLevel] nvarchar(128) N'$.OptimizationLevel'
    )
    WHERE [StatementOrdinal]=1
      AND [StatementType]=N'SELECT'
      AND [StatementQueryHash]=N'0x0101010101010101'
      AND [StatementSubTreeCost]=CONVERT(decimal(38,8),1)
      AND [OptimizationLevel]=N'FULL'
)
    THROW 53609,N'Direkte Attribute des materialisierten StmtSimple-Elements wurden nicht korrekt gelesen.',1;
IF (SELECT COUNT(*) FROM OPENJSON(@AnalysisJson,N'$.operatorTree') WITH ([StatementOrdinal] int N'$.StatementOrdinal',[NodeId] int N'$.NodeId') WHERE [NodeId]=1)<>2
    THROW 53602,N'Gleiche NodeIds verschiedener Statements wurden nicht getrennt erhalten.',1;
IF NOT EXISTS
(
    SELECT 1
    FROM OPENJSON(@AnalysisJson,N'$.operatorRuntime')
    WITH
    (
          [StatementOrdinal] int N'$.StatementOrdinal'
        , [NodeId] int N'$.NodeId'
        , [PairedActualRows] decimal(38,4) N'$.PairedActualRows'
        , [PairedActualRowsRead] decimal(38,4) N'$.PairedActualRowsRead'
        , [RowsReadNotReturnedPercent] decimal(19,6) N'$.RowsReadNotReturnedPercent'
        , [RuntimeMetricStatus] varchar(40) N'$.RuntimeMetricStatus'
    )
    WHERE [StatementOrdinal]=1 AND [NodeId]=1
      AND [PairedActualRows]=10 AND [PairedActualRowsRead]=100
      AND [RowsReadNotReturnedPercent]=90
      AND [RuntimeMetricStatus]='AVAILABLE'
)
    THROW 53603,N'ActualRows und ActualRowsRead wurden nicht korrekt gepaart oder berechnet.',1;
IF EXISTS
(
    SELECT 1
    FROM OPENJSON(@AnalysisJson,N'$.parametersAndVariants')
    WITH ([CompiledValue] nvarchar(4000) N'$.CompiledValue',[RuntimeValue] nvarchar(4000) N'$.RuntimeValue')
    WHERE [CompiledValue] IS NOT NULL OR [RuntimeValue] IS NOT NULL
)
    THROW 53604,N'DERIVED_ONLY hat konkrete Parameterwerte ausgegeben.',1;
GO

DECLARE @EvidenceJson nvarchar(max),@EvidenceStatus varchar(40),@EvidencePartial bit;
EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @StatisticsIoText=N'Table ''ExampleObject''. Scan count 1, logical reads 8, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.'
    , @StatisticsTimeText=N'SQL Server Execution Times: CPU time = 1 ms, elapsed time = 2 ms.'
    , @ResultSetArt='NONE'
    , @Json=@EvidenceJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@EvidenceStatus OUTPUT
    , @IsPartialOut=@EvidencePartial OUTPUT;
IF @EvidenceStatus NOT IN ('AVAILABLE','PARTIAL') OR ISJSON(@EvidenceJson)<>1
    THROW 53605,N'Der Evidence-Generator lieferte kein gültiges JSON.',1;
IF TRY_CONVERT(bigint,JSON_VALUE(@EvidenceJson,N'$.statisticsIo[0].logicalReads'))<>8
    THROW 53606,N'STATISTICS IO wurde nicht strukturiert erkannt.',1;
IF TRY_CONVERT(bigint,JSON_VALUE(@EvidenceJson,N'$.statisticsTime[0].elapsedMs'))<>2
    THROW 53607,N'STATISTICS TIME wurde nicht strukturiert erkannt.',1;
IF JSON_VALUE(@EvidenceJson,N'$.statisticsIo[0].rawLine') IS NOT NULL
    THROW 53608,N'HASH_ONLY hat den Rohtext unerwartet ausgegeben.',1;
GO
