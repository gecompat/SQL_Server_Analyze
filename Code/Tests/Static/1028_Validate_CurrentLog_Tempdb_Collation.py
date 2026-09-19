#!/usr/bin/env python3
"""Validate explicit temp-table collation in Current Log."""
from __future__ import annotations
import argparse
import re
from pathlib import Path

TABLE_REQUIREMENTS = {"#CurrentLog_DatabaseCandidates": 5, "#CurrentLog_DatabaseCandidateWarnings": 3, "#CurrentLog_Result": 8, "#CurrentLog_Errors": 4}
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("Current Log tempdb-collation validator self-test passed.")
        return 0
    if args.repository_root is None:
        parser.error("--repository-root is required unless --self-test is used")
    source = (args.repository_root / "Code/02_CurrentState/090_USP_CurrentLog.sql").read_text(encoding="utf-8-sig")
    failures = [name for name, count in TABLE_REQUIREMENTS.items() if (match := re.search(rf"CREATE TABLE \[{re.escape(name)}\](.*?);", source, re.DOTALL)) is None or match.group(1).count(COLLATION) < count]
    if failures:
        print("Current Log tempdb-collation validation failed: " + ", ".join(failures))
        return 1
    print("Current Log tempdb-collation validation passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
