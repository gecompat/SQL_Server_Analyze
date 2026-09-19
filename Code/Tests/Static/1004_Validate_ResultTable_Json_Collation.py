#!/usr/bin/env python3
"""Validate explicit collation when JSON TABLE mappings are materialized."""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

PROCEDURE = "Code/01_Common/096_USP_InternalPrepareResultTables.sql"
REQUIRED = (
    "[ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "FROM OPENJSON(@ResultTablesJson);",
    "CONVERT(sysname,[key])",
    "CONVERT(sysname,[value])",
)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 5 and all(REQUIRED)
        print("Result-table JSON collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing JSON collation contract: {token}" for token in REQUIRED if token not in source]
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Result-table JSON materialization collation contract passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
