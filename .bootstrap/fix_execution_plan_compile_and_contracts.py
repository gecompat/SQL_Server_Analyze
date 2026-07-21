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


def procedure_signature(sql_text: str, procedure_name: str) -> str:
    match = re.search(
        rf'(?ims)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[{re.escape(procedure_name)}\]\s*(.*?)^\s*AS\s*$',
        sql_text,
    )
    if not match:
        raise RuntimeError(f'Procedure signature not found: {procedure_name}')
    return match.group(1).strip()


def parameter_rows(procedure_name: str, signature: str) -> list[list[str]]:
    no_comments = re.sub(r'(?m)--.*$', '', signature)
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
            raise RuntimeError(f'Unparsed parameter declaration: {declaration}')
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


def table_schema(sql_text: str, table_name: str) -> str:
    match = re.search(rf'CREATE\s+TABLE\s+\[{re.escape(table_name)}\]\s*\(', sql_text, re.IGNORECASE)
    if not match:
        raise RuntimeError(f'Temp table not found: {table_name}')
    start = match.end() - 1
    depth = 0
    in_string = False
    index = start
    while index < len(sql_text):
        char = sql_text[index]
        if char == "'":
            if in_string and index + 1 < len(sql_text) and sql_text[index + 1] == "'":
                index += 2
                continue
            in_string = not in_string
        elif not in_string:
            if char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
                if depth == 0:
                    body = sql_text[start + 1:index]
                    return re.sub(r'\s+', ' ', body).strip().rstrip(',')
        index += 1
    raise RuntimeError(f'Unclosed temp table: {table_name}')


# 1. SQL Server requires an XML method before a nodes() alias is projected.
xml_paths = [
    'Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql',
    'Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql',
    'Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql',
    'Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql',
]
for path in xml_paths:
    text = read(path)
    text, count = re.subn(
        r'(?P<node>\[[A-Za-z][A-Za-z0-9_]*\]\.\[n\])(?!\s*\.)',
        lambda match: match.group('node') + ".query('.')",
        text,
    )
    if count == 0:
        raise RuntimeError(f'No direct nodes() alias projection found in {path}')
    write(path, text)

# 2. The two new public procedures increase the canonical count from 88 to 90.
validator_path = 'Code/Tests/Static/900_Validate_Analysis_Documentation.ps1'
validator = read(validator_path)
validator = validator.replace('if ($referenceNames.Count -ne 88)', 'if ($referenceNames.Count -ne 90)')
validator = validator.replace('Expected 88 reference procedures', 'Expected 90 reference procedures')
validator = validator.replace('if ($sourceProcedureNames.Count -ne 88)', 'if ($sourceProcedureNames.Count -ne 90)')
validator = validator.replace('Expected 88 canonical SQL procedures', 'Expected 90 canonical SQL procedures')
validator = validator.replace('if ($pageNames.Count -ne 88)', 'if ($pageNames.Count -ne 90)')
validator = validator.replace('Expected 88 procedure pages', 'Expected 90 procedure pages')
write(validator_path, validator)

# 3. Synchronize the Showplan public reference signature.
showplan_source_path = 'Code/04_PlanCache/050_USP_ShowplanAnalysis.sql'
showplan_sql = read(showplan_source_path)
showplan_signature = procedure_signature(showplan_sql, 'USP_ShowplanAnalysis')
reference_path = 'Documentation/Reference/Procedure_Reference.md'
reference = read(reference_path)
section_pattern = re.compile(
    r'(?ms)(^## `\[monitor\]\.\[USP_ShowplanAnalysis\]`\s*$\s*'
    r'Quelle:\s*`Code/04_PlanCache/050_USP_ShowplanAnalysis\.sql`\s*$\s*'
    r'```sql\s*$).*?(^```\s*$)',
)
reference, count = section_pattern.subn(
    lambda match: match.group(1) + '\n' + showplan_signature + '\n' + match.group(2),
    reference,
)
if count != 1:
    raise RuntimeError(f'Expected one Showplan reference section, replaced {count}.')
write(reference_path, reference)

# 4. Synchronize Showplan parameter inventory.
parameters_path = 'Metadata/Inventory/Parameters.csv'
parameter_lines = read(parameters_path).splitlines()
retained_parameters = [parameter_lines[0]]
for line in parameter_lines[1:]:
    if not line.strip():
        continue
    row = next(csv.reader([line]))
    if row[0] != 'USP_ShowplanAnalysis':
        retained_parameters.append(line)
retained_parameters.extend(csv_line(row) for row in parameter_rows('USP_ShowplanAnalysis', showplan_signature))
write(parameters_path, '\n'.join(retained_parameters) + '\n')

# 5. Synchronize the exported Showplan findings schema.
resultsets_path = 'Metadata/Inventory/ResultSets.csv'
result_lines = read(resultsets_path).splitlines()
retained_results = [result_lines[0]]
for line in result_lines[1:]:
    if not line.strip():
        continue
    row = next(csv.reader([line]))
    if not (row[0] == 'USP_ShowplanAnalysis' and row[1] == 'findings'):
        retained_results.append(line)
showplan_schema = table_schema(showplan_sql, '#ShowplanAnalysis_Findings')
retained_results.append(csv_line([
    'USP_ShowplanAnalysis', 'findings', '1', '1', '2',
    '#ShowplanAnalysis_Findings', '1', showplan_schema,
    'Keine priorisierten Showplan-Findings',
]))
write(resultsets_path, '\n'.join(retained_results) + '\n')

# 6. Keep human-readable coverage statements current.
for path in [
    'Documentation/Analysis_Guides/Object_Index.md',
    'Documentation/Analysis_Guides/Procedures/README.md',
]:
    text = read(path)
    text = re.sub(r'alle (?:85|87|88) Procedures', 'alle 90 Procedures', text)
    write(path, text)

print('Execution-plan XML projections and public contracts synchronized.')
