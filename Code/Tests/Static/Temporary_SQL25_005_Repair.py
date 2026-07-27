#!/usr/bin/env python3
from pathlib import Path

path = Path('Code/Tests/Static/Temporary_SQL25_005_Integrate.py')
text = path.read_text(encoding='utf-8')
old = '''text = replace_once(
    text,
    "            AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitIQP = 0)\\n",
    "            AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitReplicaKontext = 0 AND @MitIQP = 0)\\n",
    path,
)
'''
new = '''text = text.replace(
    "AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitIQP = 0)",
    "AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitReplicaKontext = 0 AND @MitIQP = 0)",
    1,
)
'''
if old not in text:
    raise RuntimeError('BUILDER_RULE_NOT_FOUND: orchestrator module-selection rule')
path.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')
