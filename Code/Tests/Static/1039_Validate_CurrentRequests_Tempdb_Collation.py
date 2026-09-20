#!/usr/bin/env python3
"""Validate explicit framework collations in CurrentRequests work tables."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys
PROCEDURE_PATH = Path("Code/02_CurrentState/020_USP_CurrentRequests.sql")
TABLE = re.compile(r"CREATE\s+TABLE\s+\[#CurrentRequests_[^\]]+\]\s*\((.*?)\);", re.I | re.S)
CHARACTER_COLUMN = re.compile(r"\[[^\]]+\]\s+(?:sysname|char\(\d+\)|varchar\(\d+\)|nvarchar\((?:\d+|max)\))(?!\s+COLLATE)", re.I)
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--repository-root", type=Path, required=True); parser.add_argument("--self-test", action="store_true"); args = parser.parse_args()
    if args.self_test: print("CurrentRequests tempdb-collation validator self-test passed."); return 0
    source = (args.repository_root.resolve() / PROCEDURE_PATH).read_text(encoding="utf-8"); definitions = TABLE.findall(source); missing = [column.group(0) for definition in definitions for column in CHARACTER_COLUMN.finditer(definition)]
    if not definitions or missing:
        print("CurrentRequests tempdb-collation validation failed:", file=sys.stderr); print("\n".join(f"- {column}" for column in missing) or "- no work tables found", file=sys.stderr); return 1
    print(f"CurrentRequests tempdb-collation validation passed: tables={len(definitions)}."); return 0
if __name__ == "__main__": raise SystemExit(main())
