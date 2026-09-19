#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Current Waits procedure."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PROCEDURE = "Code/02_CurrentState/040_USP_CurrentWaits.sql"
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
TABLE_REQUIREMENTS = {
    "#CurrentWaits_Tasks": 22,
    "#CurrentWaits_A": 1,
    "#CurrentWaits_B": 1,
    "#CurrentWaits_RawInstance": 2,
    "#CurrentWaits_Instance": 11,
    "#CurrentWaits_Warnings": 2,
    "#CurrentWaits_SourceWaitingTasks": 2,
    "#CurrentWaits_SourceSessions": 4,
    "#CurrentWaits_SourceRequests": 2,
    "#CurrentWaits_SourceSqlText": 1,
}


def validate(repository_root: Path) -> list[str]:
    source = (repository_root / PROCEDURE).read_text(encoding="utf-8-sig")
    findings: list[str] = []
    for table_name, required_count in TABLE_REQUIREMENTS.items():
        match = re.search(
            rf"CREATE TABLE \[{re.escape(table_name)}\](.*?);",
            source,
            flags=re.DOTALL,
        )
        if match is None:
            findings.append(f"Missing local table definition: {table_name}")
            continue
        actual_count = match.group(1).count(COLLATION)
        if actual_count < required_count:
            findings.append(
                f"{table_name} expected at least {required_count} explicit collations, found {actual_count}"
            )
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        assert len(TABLE_REQUIREMENTS) == 10
        assert sum(TABLE_REQUIREMENTS.values()) == 48
        assert COLLATION.endswith("CP1_CS_AS")
        print("Current Waits tempdb-collation validator self-test passed.")
        return 0

    findings = validate(args.repository_root)
    if findings:
        print("Current Waits tempdb-collation validation failed:")
        for finding in findings:
            print(f"- {finding}")
        return 1

    print("Current Waits tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
