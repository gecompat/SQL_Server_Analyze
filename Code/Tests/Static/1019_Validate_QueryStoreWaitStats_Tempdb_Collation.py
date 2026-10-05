#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Query Store Wait Stats procedure."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PROCEDURE = "Code/05_QueryStore/030_USP_QueryStoreWaitStats.sql"
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
TABLE_REQUIREMENTS = {
    "#QueryStoreWaitStats_DatabaseCandidates": 5,
    "#QueryStoreWaitStats_Result": 8,
    "#QueryStoreWaitStats_Errors": 3,
}


def validate(repository_root: Path) -> list[str]:
    source = (repository_root / PROCEDURE).read_text(encoding="utf-8-sig")
    findings: list[str] = []
    for table_name, required_count in TABLE_REQUIREMENTS.items():
        match = re.search(rf"CREATE TABLE \[{re.escape(table_name)}\](.*?);", source, flags=re.DOTALL)
        if match is None or match.group(1).count(COLLATION) < required_count:
            findings.append(table_name)
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(TABLE_REQUIREMENTS) == 3 and sum(TABLE_REQUIREMENTS.values()) == 16
        print("Query Store Wait Stats tempdb-collation validator self-test passed.")
        return 0
    findings = validate(args.repository_root)
    if findings:
        print("Query Store Wait Stats tempdb-collation validation failed: " + ", ".join(findings))
        return 1
    print("Query Store Wait Stats tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
