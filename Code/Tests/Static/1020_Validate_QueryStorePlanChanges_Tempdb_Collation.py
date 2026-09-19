#!/usr/bin/env python3
"""Validate explicit temp-table collation in Query Store Plan Changes."""
from __future__ import annotations
import argparse
import re
from pathlib import Path

PROCEDURE = "Code/05_QueryStore/040_USP_QueryStorePlanChanges.sql"
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
REQUIRED = {"#QueryStorePlanChanges_DatabaseCandidates": 5, "#QueryStorePlanChanges_Summary": 7, "#QueryStorePlanChanges_Plans": 9, "#QueryStorePlanChanges_Errors": 3}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert sum(REQUIRED.values()) == 24
        print("Query Store Plan Changes tempdb-collation validator self-test passed.")
        return 0
    source = (args.repository_root / PROCEDURE).read_text(encoding="utf-8-sig")
    failed = [name for name, count in REQUIRED.items() if (match := re.search(rf"CREATE TABLE \[{re.escape(name)}\](.*?);", source, re.DOTALL)) is None or match.group(1).count(COLLATION) < count]
    if failed:
        print("Query Store Plan Changes tempdb-collation validation failed: " + ", ".join(failed))
        return 1
    print("Query Store Plan Changes tempdb-collation validation passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
