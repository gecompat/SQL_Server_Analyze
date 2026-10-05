#!/usr/bin/env python3
"""Validate explicit framework collations in Execution Plan Analysis work tables."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys

PROCEDURE_PATH = Path("Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql")
CHARACTER_COLUMN = re.compile(r"\[[^\]]+\]\s+(?:sysname|varchar\(\d+\)|nvarchar\((?:\d+|max)\))(?!\s+COLLATE)", re.I)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert CHARACTER_COLUMN.search("[Name] nvarchar(max)") is not None
        assert CHARACTER_COLUMN.search("[Name] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS") is None
        print("Execution Plan Analysis tempdb-collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE_PATH).read_text(encoding="utf-8")
    definitions = re.findall(r"CREATE\s+TABLE\s+\[#ExecutionPlanAnalysis_[^\]]+\]\s*\((.*?)\);", source, re.I | re.S)
    if not definitions:
        print("Execution Plan Analysis tempdb-collation validation failed: no work tables found.", file=sys.stderr)
        return 1
    missing = [column.group(0) for definition in definitions for column in CHARACTER_COLUMN.finditer(definition)]
    if missing:
        print("Execution Plan Analysis tempdb-collation validation failed:", file=sys.stderr)
        print("\n".join(f"- {column}" for column in missing), file=sys.stderr)
        return 1
    print(f"Execution Plan Analysis tempdb-collation validation passed: tables={len(definitions)}.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
