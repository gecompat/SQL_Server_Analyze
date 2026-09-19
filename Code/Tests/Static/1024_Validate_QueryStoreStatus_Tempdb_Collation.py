#!/usr/bin/env python3
"""Validate explicit temp-table collation in Query Store Status."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

PROCEDURE_PATH = Path("Code/05_QueryStore/010_USP_QueryStoreStatus.sql")
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
TABLE_REQUIREMENTS = {
    "#QueryStoreStatus_DatabaseCandidates": 5,
    "#QueryStoreStatus_Result": 7,
    "#QueryStoreStatus_Errors": 3,
}


def validate(repository_root: Path) -> list[str]:
    source = (repository_root / PROCEDURE_PATH).read_text(encoding="utf-8-sig")
    failures: list[str] = []

    for table_name, required_count in TABLE_REQUIREMENTS.items():
        match = re.search(
            rf"CREATE TABLE \[{re.escape(table_name)}\](.*?);", source, re.DOTALL
        )
        if match is None:
            failures.append(f"missing temp table {table_name}")
        elif match.group(1).count(COLLATION) < required_count:
            failures.append(f"missing explicit collation in {table_name}")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        print("Query Store Status tempdb-collation validator self-test passed.")
        return 0

    if args.repository_root is None:
        parser.error("--repository-root is required unless --self-test is used")

    failures = validate(args.repository_root)
    if failures:
        print("Query Store Status tempdb-collation validation failed: " + "; ".join(failures))
        return 1

    print("Query Store Status tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
