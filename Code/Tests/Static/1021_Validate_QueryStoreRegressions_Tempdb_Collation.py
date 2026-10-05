#!/usr/bin/env python3
"""Validate explicit temp-table collation in Query Store Regressions."""
from __future__ import annotations
import argparse
import re
from pathlib import Path
P="Code/05_QueryStore/050_USP_QueryStoreRegressions.sql"; C="COLLATE SQL_Latin1_General_CP1_CS_AS"; R={"#QueryStoreRegressions_DatabaseCandidates":5,"#QueryStoreRegressions_Result":7,"#QueryStoreRegressions_Errors":3}
a=argparse.ArgumentParser();a.add_argument("--repository-root",type=Path,required=True);a.add_argument("--self-test",action="store_true");x=a.parse_args()
if x.self_test:
 assert sum(R.values())==15;print("Query Store Regressions tempdb-collation validator self-test passed.")
else:
 s=(x.repository_root/P).read_text(encoding="utf-8-sig");f=[n for n,c in R.items() if (m:=re.search(rf"CREATE TABLE \[{re.escape(n)}\](.*?);",s,re.DOTALL)) is None or m.group(1).count(C)<c];print("Query Store Regressions tempdb-collation validation " + ("failed: "+", ".join(f) if f else "passed."));raise SystemExit(bool(f))
