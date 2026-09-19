#!/usr/bin/env python3
"""Validate explicit framework collation on blocked-process temporary tables."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/06_ExtendedEvents/040_USP_ExtendedEventsBlockedProcesses.sql"
REQUIRED = (
    "[#ExtendedEventsBlockedProcesses_Raw]([SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SessionName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[#ExtendedEventsBlockedProcesses_ReportSummary]([ReportId] int,[SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[#ExtendedEventsBlockedProcesses_BlockedProcesses]([ReportId] int,[ReportTimeUtc] datetime2(7),[SessionId] int NULL,[ExecutionContextId] int NULL,[ProcessStatus] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[#ExtendedEventsBlockedProcesses_BlockingProcesses]([ReportId] int,[ReportTimeUtc] datetime2(7),[SessionId] int NULL,[ExecutionContextId] int NULL,[ProcessStatus] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS",
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
        print("Blocked-process collation validator self-test passed.")
        return 0
    errors = validate(args.repository_root.resolve())
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Blocked-process temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
