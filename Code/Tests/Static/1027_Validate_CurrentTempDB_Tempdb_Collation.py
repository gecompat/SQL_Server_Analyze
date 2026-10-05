#!/usr/bin/env python3
"""Validate explicit temp-table collation in Current TempDB."""
from __future__ import annotations
import argparse
import re
from pathlib import Path

TABLE_REQUIREMENTS = {
    "#CurrentTempDB_Sessions": 4, "#CurrentTempDB_Files": 3,
    "#CurrentTempDB_TempdbGovernance": 5, "#CurrentTempDB_Warnings": 2,
    "#CurrentTempDB_SourceSessions": 4, "#CurrentTempDB_SourceGroupCatalog": 1,
    "#CurrentTempDB_SourceGroupRuntime": 1, "#CurrentTempDB_SourcePools": 1,
}
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("Current TempDB tempdb-collation validator self-test passed.")
        return 0
    if args.repository_root is None:
        parser.error("--repository-root is required unless --self-test is used")
    source = (args.repository_root / "Code/02_CurrentState/070_USP_CurrentTempDB.sql").read_text(encoding="utf-8-sig")
    failures = [name for name, count in TABLE_REQUIREMENTS.items() if (match := re.search(rf"CREATE TABLE \[{re.escape(name)}\](.*?);", source, re.DOTALL)) is None or match.group(1).count(COLLATION) < count]
    if failures:
        print("Current TempDB tempdb-collation validation failed: " + ", ".join(failures))
        return 1
    print("Current TempDB tempdb-collation validation passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
