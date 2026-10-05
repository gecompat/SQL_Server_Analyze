#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Query Store Hints procedure."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/05_QueryStore/070_USP_QueryStoreHints.sql"
REQUIRED = (
    "[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and all(REQUIRED)
        print("Query Store Hints temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Query Store Hints collation contract: {token}" for token in REQUIRED if token not in source]
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Query Store Hints temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
