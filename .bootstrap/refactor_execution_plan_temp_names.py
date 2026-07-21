#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def update(path: str, replacements: list[tuple[str, str]], add_lock_timeout: bool = False) -> None:
    target = root / path
    text = target.read_text(encoding='utf-8')
    if add_lock_timeout and 'SET NOCOUNT ON;\n    SET LOCK_TIMEOUT 0;' not in text:
        text = text.replace('SET NOCOUNT ON;\n', 'SET NOCOUNT ON;\n    SET LOCK_TIMEOUT 0;\n', 1)
    for old, new in replacements:
        text = text.replace(old, new)
    target.write_text(text, encoding='utf-8', newline='\n')


update(
    'Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql',
    [
        ('#EPE_Metadata_ObjectReferences', '#InternalCollectExecutionPlanMetadata_ObjectReferences'),
        ('#EPE_Metadata_RelevantColumns', '#InternalCollectExecutionPlanMetadata_RelevantColumns'),
        ('#EPE_Metadata_CandidateStatistics', '#InternalCollectExecutionPlanMetadata_CandidateStatistics'),
        ('#EPE_Metadata_PredicateValues', '#InternalCollectExecutionPlanMetadata_PredicateValues'),
        ('#EPE_', '#CreateExecutionEvidenceJson_'),
    ],
    add_lock_timeout=True,
)
update(
    'Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql',
    [
        ('#EPA_InternalStatementXml', '#InternalAnalyzeExecutionPlan_StatementXml'),
        ('#EPA_InternalEdges', '#InternalAnalyzeExecutionPlan_Edges'),
        ('#EPA_', '#ExecutionPlanAnalysis_'),
    ],
)
update(
    'Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql',
    [('#EPE_', '#CreateExecutionEvidenceJson_')],
)
update(
    'Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql',
    [('#EPA_', '#ExecutionPlanAnalysis_')],
)

for path in [
    'Metadata/Inventory/ResultSets.csv',
    'Documentation/Architecture/Execution_Plan_Analysis_Design.md',
    'Documentation/Architecture/Execution_Plan_Analysis_Installation_Contract.md',
]:
    target = root / path
    text = target.read_text(encoding='utf-8')
    text = text.replace('#EPE_', '#CreateExecutionEvidenceJson_')
    text = text.replace('#EPA_', '#ExecutionPlanAnalysis_')
    target.write_text(text, encoding='utf-8', newline='\n')

print('Execution-plan temp names refactored.')
