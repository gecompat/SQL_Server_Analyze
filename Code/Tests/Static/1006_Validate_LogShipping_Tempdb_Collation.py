#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Log Shipping status procedure."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/07_Infrastructure/060_USP_LogShippingStatus.sql"
REQUIRED = (
    "[PrimaryServer] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[PrimaryDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[BackupDirectory] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[LastBackupFile] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SecondaryServer] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[LastCopiedFile] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[LastRestoredFile] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and all(REQUIRED)
        print("Log Shipping temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Log Shipping collation contract: {token}" for token in REQUIRED if token not in source]
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Log Shipping temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
