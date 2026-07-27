#!/usr/bin/env python3
from pathlib import Path
import subprocess

root = Path('.').resolve()

readme = root / 'README.md'
text = readme.read_text(encoding='utf-8-sig')
old = 'Der aktuelle Inventory-Vertrag umfasst 98 öffentliche Procedures und 68 unterstützende Objekte: acht Views, 27 TVFs, 16 interne Procedures und 17 Tabellen. Jedes der insgesamt 166 Objekte besitzt einen eindeutigen Referenzpfad.'
new = 'Der aktuelle Inventory-Vertrag umfasst 99 öffentliche Procedures und 69 unterstützende Objekte: acht Views, 28 TVFs, 16 interne Procedures und 17 Tabellen. Jedes der insgesamt 168 Objekte besitzt einen eindeutigen Referenzpfad.'
if old not in text:
    raise RuntimeError('ROOT_README_INVENTORY_MARKER_NOT_FOUND')
readme.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')

plan = root / 'Documentation/Architecture/SQL_Server_Lab_Example_Integration_Plan.md'
text = plan.read_text(encoding='utf-8-sig')
plan.write_text(text.replace('Implementierungswelle', 'Umsetzungsabschnitt'), encoding='utf-8', newline='\n')

reference = root / 'Documentation/Reference/Object_Reference.md'
text = reference.read_text(encoding='utf-8-sig')
text = text.replace('Stand: 2026-07-21', 'Stand: 2026-07-27', 1)
text = text.replace('| Table-Valued Functions (TVFs) | 27 | ein Abschnitt je TVF |', '| Table-Valued Functions (TVFs) | 28 | ein Abschnitt je TVF |', 1)
nav_marker = '| [`TVF_QueryStoreWaitCategoryInfo`](#monitortvf_querystorewaitcategoryinfo) | `monitor` | `Code/01_Common/076_TVF_QueryStoreWaitCategoryInfo.sql` |\n'
nav_row = '| [`TVF_QueryStoreReplicaRoleInfo`](#monitortvf_querystorereplicaroleinfo) | `monitor` | `Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql` |\n'
if nav_row not in text:
    if nav_marker not in text:
        raise RuntimeError('TVF_NAVIGATION_MARKER_NOT_FOUND')
    text = text.replace(nav_marker, nav_marker + nav_row, 1)
section = '''### `[monitor].[TVF_QueryStoreReplicaRoleInfo]`

Quelle: `Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet den von SQL Server 2025 gelieferten `role_type` einer stabilen Query-Store-Rollen- und Scopeklasse zu. |
| Schnittstelle | Inline TVF; Eingabe: `@RoleType tinyint`. Die Funktion liefert Rollenbezeichnung, Rollenklasse, Primary-/Secondary-/Named-Replica-Flags und eine feste Aussagegrenze. |
| Verwendung | `USP_QueryStoreReplicaAnalysis` verwendet die Funktion nach der capability-adaptiven Katalogprüfung. Ein Direktaufruf eignet sich nur für Entwicklung und Vertragstests. |
| Last und Sperren | Konstante Projektion ohne Katalog-, DMV- oder Tabellenzugriff. Die Funktion erzeugt weder I/O noch Sperren auf Benutzerdaten. |
| Vertrag | Unterstützende TVF. Die Rollenabbildung beschreibt beobachtete Query-Store-Evidenz und ist keine aktuelle Availability-Group-, Synchronitäts- oder Healthaussage. |

'''
if '### `[monitor].[TVF_QueryStoreReplicaRoleInfo]`' not in text:
    marker = '## Interne Procedures\n'
    if marker not in text:
        raise RuntimeError('TVF_SECTION_MARKER_NOT_FOUND')
    text = text.replace(marker, section + marker, 1)
reference.write_text(text, encoding='utf-8', newline='\n')

for relative in (
    'Code/Tests/Static/Temporary_SQL25_005_Static_Findings.txt',
    '.github/workflows/temporary-sql25-005-static-diagnostic.yml',
    '.github/workflows/temporary-sql25-005-doc-repair.yml',
):
    path = root / relative
    if path.exists():
        path.unlink()

original_workflow = subprocess.check_output(
    ['git', 'show', 'origin/main:.github/workflows/commit-message-validation.yml'],
    text=True,
    encoding='utf-8',
)
(root / '.github/workflows/commit-message-validation.yml').write_text(original_workflow, encoding='utf-8', newline='\n')

Path(__file__).unlink()
print('SQL25-005 documentation contracts repaired')
