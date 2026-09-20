import argparse,re,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args()
if a.self_test:print('CheckAnalyseAccess tempdb-collation validator self-test passed.');raise SystemExit()
s=(a.repository_root/'Code/01_Common/050_USP_CheckAnalyseAccess.sql').read_text();d=re.findall(r'CREATE\s+TABLE\s+\[#CheckAnalyseAccess_[^\]]+\]\s*\((.*?)\);',s,re.I|re.S);m=[x.group() for q in d for x in re.finditer(r'\[[^]]+\]\s+(?:sysname|varchar\(\d+\)|nvarchar\((?:\d+|max)\))(?!\s+COLLATE)',q,re.I)]
if not d or m:print('\n'.join(m),file=sys.stderr);raise SystemExit(1)
print(f'CheckAnalyseAccess tempdb-collation validation passed: tables={len(d)}.')
