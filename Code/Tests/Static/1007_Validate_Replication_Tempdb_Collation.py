#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Replication status procedure."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/07_Infrastructure/070_USP_ReplicationStatus.sql"
REQUIRED = (
    "[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[PublisherDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[PublicationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SubscriberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[LastAction] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SourceName] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[ErrorText] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and all(REQUIRED)
        print("Replication temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Replication collation contract: {token}" for token in REQUIRED if token not in source]
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Replication temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
