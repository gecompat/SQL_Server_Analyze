#!/usr/bin/env python3
"""Validate explicit framework collations in CurrentBlocking work tables."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys
P=Path('Code/02_CurrentState/030_USP_CurrentBlocking.sql')
T=re.compile(r'CREATE\s+TABLE\s+\[#CurrentBlocking_[^\]]+\]\s*\((.*?)\);',re.I|re.S)
C=re.compile(r'\[[^\]]+\]\s+(?:sysname|varchar\(\d+\)|nvarchar\((?:\d+|max)\))(?!\s+COLLATE)',re.I)
def main():
 a=argparse.ArgumentParser();a.add_argument('--repository-root',type=Path,required=True);a.add_argument('--self-test',action='store_true');x=a.parse_args()
 if x.self_test: print('CurrentBlocking tempdb-collation validator self-test passed.');return 0
 d=T.findall((x.repository_root/P).read_text(encoding='utf-8'));m=[q.group(0) for z in d for q in C.finditer(z)]
 if not d or m: print('CurrentBlocking tempdb-collation validation failed:\n'+'\n'.join(m),file=sys.stderr);return 1
 print(f'CurrentBlocking tempdb-collation validation passed: tables={len(d)}.');return 0
if __name__=='__main__':raise SystemExit(main())
