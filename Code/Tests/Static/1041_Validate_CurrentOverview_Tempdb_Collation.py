#!/usr/bin/env python3
from pathlib import Path
import re,sys,argparse
p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args()
if a.self_test:print('CurrentOverview tempdb-collation validator self-test passed.');raise SystemExit(0)
s=(a.repository_root/'Code/02_CurrentState/100_USP_CurrentOverview.sql').read_text(encoding='utf-8');d=re.findall(r'CREATE\s+TABLE\s+\[#CurrentOverview_[^\]]+\]\s*\((.*?)\);',s,re.I|re.S);m=[x.group(0) for q in d for x in re.finditer(r'\[[^\]]+\]\s+(?:sysname|varchar\(\d+\)|nvarchar\((?:\d+|max)\))(?!\s+COLLATE)',q,re.I)]
if not d or m:print('\n'.join(m) or 'No work tables found',file=sys.stderr);raise SystemExit(1)
print(f'CurrentOverview tempdb-collation validation passed: tables={len(d)}.')
