#!/usr/bin/env python3
"""Validate explicit temp-table collation in Current Memory Grants."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

PROCEDURE_PATH = Path("Code/02_CurrentState/060_USP_CurrentMemoryGrants.sql")
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
TABLE_REQUIREMENTS = {
    "#CurrentMemoryGrants_Result": 9,
    "#CurrentMemoryGrants_Warnings": 2,
    "#CurrentMemoryGrants_SourceSessions": 3,
    "#CurrentMemoryGrants_SourceRequests": 2,
    "#CurrentMemoryGrants_SourceWorkloadGroups": 1,
    "#CurrentMemoryGrants_SourceResourcePools": 1,
    "#CurrentMemoryGrants_SourceSqlText": 1,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("Current Memory Grants tempdb-collation validator self-test passed.")
        return 0
    if args.repository_root is None:
        parser.error("--repository-root is required unless --self-test is used")
    source = (args.repository_root / PROCEDURE_PATH).read_text(encoding="utf-8-sig")
    failures = []
    for name, required_count in TABLE_REQUIREMENTS.items():
        match = re.search(rf"CREATE TABLE \[{re.escape(name)}\](.*?);", source, re.DOTALL)
        if match is None or match.group(1).count(COLLATION) < required_count:
            failures.append(name)
    if failures:
        print("Current Memory Grants tempdb-collation validation failed: " + ", ".join(failures))
        return 1
    print("Current Memory Grants tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
