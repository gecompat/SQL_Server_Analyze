#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding='utf-8', newline='\n')


def csv_line(values: list[str]) -> str:
    buffer = io.StringIO(newline='')
    csv.writer(buffer, lineterminator='').writerow(values)
    return buffer.getvalue()


def signature(sql_text: str, procedure_name: str) -> str:
    match = re.search(
        rf'(?ims)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[{re.escape(procedure_name)}\]\s*(.*?)^\s*AS\s*$',
        sql_text,
    )
    if not match:
        raise RuntimeError(f'Procedure signature not found: {procedure_name}')
    return match.group(1).strip()


def parameter_rows(procedure_name: str, procedure_signature: str) -> list[list[str]]:
    no_comments = re.sub(r'(?m)--.*$', '', procedure_signature)
    normalized = re.sub(r'\s+', ' ', no_comments).strip().lstrip(',').strip()
    declarations = re.split(r',\s*(?=@[A-Za-z_])', normalized)
    pattern = re.compile(
        r'^@(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s+'
        r'(?P<type>[A-Za-z0-9_]+(?:\s*\([^)]*\))?)'
        r'(?:\s*=\s*(?P<default>.*?))?'
        r'(?P<output>\s+OUTPUT)?$',
        re.IGNORECASE,
    )
    rows: list[list[str]] = []
    for declaration in declarations:
        declaration = declaration.strip()
        match = pattern.match(declaration)
        if not match:
            raise RuntimeError(f'Unparsed declaration: {declaration}')
        default = (match.group('default') or '').strip()
        if match.group('output'):
            default = (default + ' OUTPUT').strip()
        rows.append([
            procedure_name,
            match.group('name'),
            re.sub(r'\s+', '', match.group('type')),
            default,
        ])
    return rows


procedure_path = 'Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql'
text = read(procedure_path)
text = text.replace('Version      : 1.0.0', 'Version      : 1.0.1', 1)
text = text.replace('@SessionId                      smallint        = NULL', '@SessionIds                     nvarchar(max)   = NULL', 1)
text = text.replace(
    "DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);",
    "DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);\n    DECLARE @EffectiveSessionId smallint=NULL;",
    1,
)
text = text.replace(
    "PRINT N'Genau eine Planquelle: @PlanXml, @PlanHandle, @SessionId oder @QueryStoreDatabaseName+@QueryStorePlanId.';",
    "PRINT N'Genau eine Planquelle: @PlanXml, @PlanHandle, genau ein Wert in @SessionIds oder @QueryStoreDatabaseName+@QueryStorePlanId.';",
    1,
)
validation_anchor = "    DECLARE @PlanSourceGroupCount int="
validation_block = """    IF @StatusCodeOut='AVAILABLE'
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

"""
if validation_block.strip() not in text:
    if validation_anchor not in text:
        raise RuntimeError('Plan source count anchor not found.')
    text = text.replace(validation_anchor, validation_block + validation_anchor, 1)
text = text.replace('+ CASE WHEN @SessionId IS NOT NULL THEN 1 ELSE 0 END', '+ CASE WHEN @EffectiveSessionId IS NOT NULL THEN 1 ELSE 0 END', 1)
text = text.replace('ELSE IF @SessionId IS NOT NULL', 'ELSE IF @EffectiveSessionId IS NOT NULL', 1)
text = text.replace('[sys].[dm_exec_query_statistics_xml](@SessionId)', '[sys].[dm_exec_query_statistics_xml](@EffectiveSessionId)')
write(procedure_path, text)

installer_path = 'Code/Install/Install_ExecutionPlanAnalysis.sql'
installer = read(installer_path)
include_block = ':r ../01_Common/078_TVF_ParsePipeList.sql\n:r ../01_Common/085_TVF_ParseBigintList.sql\n'
anchor = ':r ../01_Common/083a_USP_InternalCheckAnalysisPath.sql\n'
if ':r ../01_Common/078_TVF_ParsePipeList.sql' not in installer:
    installer = installer.replace(anchor, include_block + anchor, 1)
write(installer_path, installer)

manifest_path = 'Metadata/Inventory/ExecutionPlanAnalysisDependencies.csv'
manifest_rows = list(csv.DictReader(io.StringIO(read(manifest_path))))
existing = {row['ObjectName'] for row in manifest_rows}
additional = []
if 'TVF_ParsePipeList' not in existing:
    additional.append({'ObjectType':'FUNCTION','ObjectName':'TVF_ParsePipeList','SourcePath':'Code/01_Common/078_TVF_ParsePipeList.sql','StandaloneRequired':'1','FrameworkIntegrationRole':'shared list parser'})
if 'TVF_ParseBigintList' not in existing:
    additional.append({'ObjectType':'FUNCTION','ObjectName':'TVF_ParseBigintList','SourcePath':'Code/01_Common/085_TVF_ParseBigintList.sql','StandaloneRequired':'1','FrameworkIntegrationRole':'shared numeric list parser'})
manifest_rows.extend(additional)
order = [
    'monitor schema','VW_AnalyseClassCatalog','VW_AnalyseAccessPolicy','VW_AnalyseAccessCurrent',
    'TVF_ParsePipeList','TVF_ParseBigintList','InternalCheckAnalysisPath','InternalWriteResultTable',
    'InternalPrepareResultTables','InternalEmitConsoleResult','PlanAnalysisProfile',
    'PlanAnalysisRuleThreshold','PlanAnalysisProfileAssignment','TVF_ParseStatisticsIoText',
    'TVF_ParseStatisticsTimeText','TVF_ExecutionPlanObjectReferences',
    'TVF_ExecutionPlanStatisticsUsage','TVF_ExecutionPlanColumnReferences',
    'InternalCollectExecutionPlanMetadata','InternalAnalyzeExecutionPlan',
    'USP_CreateExecutionEvidenceJson','USP_ExecutionPlanAnalysis','USP_ShowplanAnalysis','USP_PlanCacheAnalysis'
]
rank = {name: index + 1 for index, name in enumerate(order)}
manifest_rows.sort(key=lambda row: rank[row['ObjectName']])
output = io.StringIO(newline='')
writer = csv.DictWriter(output, fieldnames=['InstallOrdinal','ObjectType','ObjectName','SourcePath','StandaloneRequired','FrameworkIntegrationRole'], lineterminator='\n')
writer.writeheader()
for row in manifest_rows:
    row['InstallOrdinal'] = str(rank[row['ObjectName']])
    writer.writerow(row)
write(manifest_path, output.getvalue())

test_path = 'Code/Tests/Integration/192_ExecutionPlanAnalysis_Installer_Contract.ps1'
test_text = read(test_path)
if "'078_TVF_ParsePipeList.sql'" not in test_text:
    test_text = test_text.replace(
        "'040_VW_AnalyseAccessCurrent.sql','083a_USP_InternalCheckAnalysisPath.sql'",
        "'040_VW_AnalyseAccessCurrent.sql','078_TVF_ParsePipeList.sql','085_TVF_ParseBigintList.sql','083a_USP_InternalCheckAnalysisPath.sql'",
        1,
    )
write(test_path, test_text)

for path in [
    'Documentation/Architecture/Execution_Plan_Analysis_Design.md',
    'Documentation/Architecture/Execution_Plan_Analysis_Installation_Contract.md',
    'Documentation/Analysis_Guides/Procedures/USP_ExecutionPlanAnalysis.md',
]:
    doc = read(path).replace('@SessionId', '@SessionIds')
    write(path, doc)

procedure_text = read(procedure_path)
procedure_signature = signature(procedure_text, 'USP_ExecutionPlanAnalysis')
reference_path = 'Documentation/Reference/Procedure_Reference.md'
reference = read(reference_path)
pattern = re.compile(
    r'(?ms)(^## `\[monitor\]\.\[USP_ExecutionPlanAnalysis\]`\s*$\s*'
    r'Quelle:\s*`Code/04_PlanCache/053_USP_ExecutionPlanAnalysis\.sql`\s*$\s*'
    r'```sql\s*$).*?(^```\s*$)'
)
reference, count = pattern.subn(lambda match: match.group(1) + '\n' + procedure_signature + '\n' + match.group(2), reference)
if count != 1:
    raise RuntimeError(f'Expected one execution-plan reference section, replaced {count}.')
write(reference_path, reference)

parameters_path = 'Metadata/Inventory/Parameters.csv'
parameter_lines = read(parameters_path).splitlines()
retained = [parameter_lines[0]]
for line in parameter_lines[1:]:
    if not line.strip():
        continue
    row = next(csv.reader([line]))
    if row[0] != 'USP_ExecutionPlanAnalysis':
        retained.append(line)
retained.extend(csv_line(row) for row in parameter_rows('USP_ExecutionPlanAnalysis', procedure_signature))
write(parameters_path, '\n'.join(retained) + '\n')

legacy_pattern = re.compile(r'@SessionId\b')
legacy_hits = []
for path in [
    ROOT / procedure_path,
    ROOT / 'Documentation/Architecture/Execution_Plan_Analysis_Design.md',
    ROOT / 'Documentation/Architecture/Execution_Plan_Analysis_Installation_Contract.md',
    ROOT / 'Documentation/Analysis_Guides/Procedures/USP_ExecutionPlanAnalysis.md',
    ROOT / reference_path,
    ROOT / parameters_path,
]:
    if legacy_pattern.search(path.read_text(encoding='utf-8')):
        legacy_hits.append(path.as_posix())
if legacy_hits:
    raise RuntimeError('Legacy session parameter remains in: ' + ', '.join(legacy_hits))

print('Canonical @SessionIds integration completed.')
