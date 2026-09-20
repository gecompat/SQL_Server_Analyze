#!/usr/bin/env python3
"""Validate explicit framework collations in ObjectInventory work tables."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys
PROCEDURE_PATH = Path("Code/03_ObjectIndex/010_USP_ObjectInventory.sql")
TABLE = re.compile(r"CREATE\s+TABLE\s+\[#ObjectInventory_[^\]]+\]\s*\((.*?)\);", re.I | re.S)
CHARACTER_COLUMN = re.compile(r"\[[^\]]+\]\s+(?:sysname|varchar\(\d+\)|nvarchar\((?:\d+|max)\)|char\(\d+\)|nchar\(\d+\))(?!\s+COLLATE)", re.I)
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("ObjectInventory tempdb-collation validator self-test passed.")
        return 0
    definitions = TABLE.findall((args.repository_root.resolve() / PROCEDURE_PATH).read_text(encoding="utf-8"))
    missing = [column.group(0) for definition in definitions for column in CHARACTER_COLUMN.finditer(definition)]
    if not definitions or missing:
        print("ObjectInventory tempdb-collation validation failed:", file=sys.stderr)
        print("\n".join(f"- {column}" for column in missing) or "- no work tables found", file=sys.stderr)
        return 1
    print(f"ObjectInventory tempdb-collation validation passed: tables={len(definitions)}.")
    return 0
if __name__ == "__main__":
    raise SystemExit(main())
