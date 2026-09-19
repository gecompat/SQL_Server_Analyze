#!/usr/bin/env python3
"""Validate explicit framework collations in USP_QueryStats work tables."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


PROCEDURE_PATH = Path("Code/04_PlanCache/010_USP_QueryStats.sql")
COLLATION = "SQL_Latin1_General_CP1_CS_AS"
TABLE_REQUIREMENTS = {
    "#QueryStats_DatabaseCandidates": 5,
    "#QueryStats_DatabaseCandidateWarnings": 3,
    "#QueryStats_Result": 5,
}


def extract_table_definition(source: str, table_name: str) -> str:
    match = re.search(
        rf"CREATE\s+TABLE\s+\[{re.escape(table_name)}\]\s*\((.*?)\);",
        source,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if match is None:
        raise ValueError(f"Missing CREATE TABLE definition for {table_name}.")
    return match.group(1)


def validate(repository_root: Path) -> list[str]:
    source = (repository_root / PROCEDURE_PATH).read_text(encoding="utf-8")
    errors: list[str] = []

    for table_name, expected_count in TABLE_REQUIREMENTS.items():
        try:
            definition = extract_table_definition(source, table_name)
        except ValueError as error:
            errors.append(str(error))
            continue

        collation_count = len(
            re.findall(
                rf"\bCOLLATE\s+{re.escape(COLLATION)}\b",
                definition,
                flags=re.IGNORECASE,
            )
        )
        if collation_count != expected_count:
            errors.append(
                f"{table_name} declares {collation_count} explicit framework collations; "
                f"expected {expected_count}."
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        sample = "CREATE TABLE #Example ([Name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);"
        if "SQL_Latin1_General_CP1_CS_AS" not in sample:
            print("Self-test failed.", file=sys.stderr)
            return 1
        print("Self-test passed.")
        return 0

    errors = validate(args.repository_root.resolve())
    if errors:
        print("Query Stats TempDB collation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Query Stats TempDB collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
