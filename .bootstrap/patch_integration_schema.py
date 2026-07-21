#!/usr/bin/env python3
from pathlib import Path

path = Path('.bootstrap/integrate_execution_plan_analysis.py')
text = path.read_text(encoding='utf-8')
needle = '''def table_schema(sql_text: str, table_name: str) -> str:
    match = re.search(rf"CREATE\\s+TABLE\\s+\\[{re.escape(table_name)}\\]\\s*\\(", sql_text, re.IGNORECASE)
    if not match:
        raise RuntimeError(f"Temp table not found: {table_name}")
'''
replacement = '''def table_schema(sql_text: str, table_name: str) -> str:
    aliases = {
        "#EPE_StatisticsIoOutput": "#EPE_StatisticsIo",
        "#EPE_StatisticsTimeOutput": "#EPE_StatisticsTime",
        "#EPE_PlanStatisticsUsageOutput": "#EPE_PlanStatisticsUsage",
        "#EPE_ObjectReferencesOutput": "#EPE_ObjectReferences",
        "#EPE_HistogramSummaryOutput": "#EPE_HistogramSummary",
        "#EPE_PredicateMappingsOutput": "#EPE_PredicateHistogramMappings",
    }
    overrides = {
        "#EPE_StatisticsCurrentOutput": "[DatabaseName] sysname NULL, [SchemaName] sysname NULL, [ObjectName] sysname NULL, [ObjectId] int NOT NULL, [StatisticsName] sysname NULL, [StatisticsId] int NOT NULL, [IsIndexStatistics] bit NOT NULL, [IsAutoCreated] bit NULL, [IsUserCreated] bit NULL, [IsFiltered] bit NULL, [FilterDefinition] nvarchar(max) NULL, [FilterDefinitionStatus] varchar(40) NOT NULL, [NoRecompute] bit NULL, [IsIncremental] bit NULL, [HasPersistedSample] bit NULL, [LeadingColumnName] sysname NULL, [LastUpdated] datetime2(7) NULL, [Rows] bigint NULL, [RowsSampled] bigint NULL, [SamplePercent] decimal(19,6) NULL, [Steps] int NULL, [UnfilteredRows] bigint NULL, [ModificationCounter] bigint NULL, [ModificationPercent] decimal(19,6) NULL, [PersistedSamplePercent] float NULL, [CollectionStatus] varchar(40) NOT NULL",
        "#EPE_HistogramStepsOutput": "[DatabaseName] sysname NULL, [SchemaName] sysname NULL, [ObjectName] sysname NULL, [StatisticsName] sysname NULL, [StatisticsId] int NOT NULL, [LeadingColumnName] sysname NULL, [StepOrdinal] int NOT NULL, [RangeHighKey] nvarchar(4000) NULL, [RangeHighKeyToken] varbinary(32) NULL, [RangeRows] float NULL, [EqualRows] float NULL, [DistinctRangeRows] bigint NULL, [AverageRangeRows] float NULL, [IsPredicateTarget] bit NOT NULL, [PredicateMatchCount] int NOT NULL, [SensitiveValueStatus] varchar(40) NOT NULL",
    }
    if table_name in overrides:
        return overrides[table_name]
    if table_name in aliases:
        return table_schema(sql_text, aliases[table_name])
    match = re.search(rf"CREATE\\s+TABLE\\s+\\[{re.escape(table_name)}\\]\\s*\\(", sql_text, re.IGNORECASE)
    if not match:
        raise RuntimeError(f"Temp table not found: {table_name}")
'''
if needle not in text:
    raise RuntimeError('Canonical table_schema function prefix was not found.')
text = text.replace(needle, replacement, 1)
text = text.replace('table_schema(evidence_sql, table_name[1:])', 'table_schema(evidence_sql, table_name)')
text = text.replace('table_schema(analysis_sql, table_name[1:])', 'table_schema(analysis_sql, table_name)')
path.write_text(text, encoding='utf-8', newline='\n')
print('Integration schema patch applied.')
