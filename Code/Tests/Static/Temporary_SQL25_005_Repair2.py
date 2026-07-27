#!/usr/bin/env python3
from pathlib import Path

path = Path('Code/Tests/Static/Temporary_SQL25_005_Integrate.py')
text = path.read_text(encoding='utf-8')
replacements = {
    'text = insert_before(text, marker, terms, path)': 'text = text.replace(marker, terms + marker, 1)',
    'text = insert_before(text, "        , (N\'USP_QueryStoreRuntimeStats\'", relations, path)': 'text = text.replace("        , (N\'USP_QueryStoreRuntimeStats\'", relations + "        , (N\'USP_QueryStoreRuntimeStats\'", 1)',
}
changed = False
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new, 1)
        changed = True
if not changed:
    raise RuntimeError('BUILDER_RULE_NOT_FOUND: search-term or relation insertion')
path.write_text(text, encoding='utf-8', newline='\n')
