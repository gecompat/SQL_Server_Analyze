#!/usr/bin/env python3
"""Validate explicit framework collations in PrepareDatabaseCandidates work tables."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


PROCEDURE_PATH = Path("Code/01_Common/083_USP_PrepareDatabaseCandidates.sql")
TABLE = re.compile(
    r"CREATE\s+TABLE\s+\[#PrepareDatabaseCandidates_[^\]]+\]\s*\((.*?)\);",
    re.IGNORECASE | re.DOTALL,
)
CHARACTER_COLUMN = re.compile(
    r"\[[^\]]+\]\s+(?:sysname|varchar\(\d+\)|nvarchar\((?:\d+|max)\))(?!\s+COLLATE)",
    re.IGNORECASE,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("PrepareDatabaseCandidates tempdb-collation validator self-test passed.")
        return 0

    source = (args.repository_root.resolve() / PROCEDURE_PATH).read_text(encoding="utf-8")
    definitions = TABLE.findall(source)
    missing = [
        column.group(0)
        for definition in definitions
        for column in CHARACTER_COLUMN.finditer(definition)
    ]
    if not definitions or missing:
        print("PrepareDatabaseCandidates tempdb-collation validation failed:", file=sys.stderr)
        print("\n".join(f"- {column}" for column in missing) or "- no work tables found", file=sys.stderr)
        return 1

    print(f"PrepareDatabaseCandidates tempdb-collation validation passed: tables={len(definitions)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
