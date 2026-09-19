#!/usr/bin/env python3
"""Validate explicit framework collation on deadlock temporary tables."""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

PROCEDURE = "Code/06_ExtendedEvents/030_USP_ExtendedEventsDeadlocks.sql"
REQUIRED = (
    "[SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "[VictimProcessId] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "[SessionName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[#ExtendedEventsDeadlocks_DeadlockProcesses]([DeadlockId] int,[DeadlockTimeUtc] datetime2(7),[ProcessId] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[#ExtendedEventsDeadlocks_DeadlockResources]([DeadlockId] int,[DeadlockTimeUtc] datetime2(7),[ResourceType] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
)
def validate(root: Path) -> list[str]:
    text = (root / PROCEDURE).read_text(encoding="utf-8-sig")
    return [f"missing {token}" for token in REQUIRED if token not in text]
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert REQUIRED and all("COLLATE SQL_Latin1_General_CP1_CS_AS" in token for token in REQUIRED)
        print("Deadlock collation validator self-test passed.")
        return 0
    errors = validate(args.repository_root.resolve())
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Deadlock temporary-table collation contract passed.")
    return 0
if __name__ == "__main__":
    raise SystemExit(main())
