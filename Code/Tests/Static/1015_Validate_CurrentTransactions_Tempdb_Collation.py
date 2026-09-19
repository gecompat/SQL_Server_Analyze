#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Current Transactions procedure."""

from __future__ import annotations

import argparse
from pathlib import Path


PROCEDURE = "Code/02_CurrentState/050_USP_CurrentTransactions.sql"
REQUIRED = {
    "[LoginName]                nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[HostName]                 nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[ProgramName]              nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[SessionStatus]            nvarchar(30)   COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[RequestStatus]            nvarchar(30)   COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[DatabaseName]             sysname        COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[StatementText]            nvarchar(max)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL": 1,
    "[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL": 2,
    "[login_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL": 1,
    "[host_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[program_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
    "[Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 1,
}


def validate(repository_root: Path) -> list[str]:
    source = (repository_root / PROCEDURE).read_text(encoding="utf-8-sig")
    return [
        f"{fragment} (expected at least {minimum}, found {source.count(fragment)})"
        for fragment, minimum in REQUIRED.items()
        if source.count(fragment) < minimum
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        assert len(REQUIRED) == 14
        assert sum(REQUIRED.values()) == 15
        assert all("COLLATE SQL_Latin1_General_CP1_CS_AS" in item for item in REQUIRED)
        print("Current Transactions tempdb-collation validator self-test passed.")
        return 0

    missing = validate(args.repository_root)
    if missing:
        print("Current Transactions tempdb-collation validation failed:")
        for fragment in missing:
            print(f"- Missing: {fragment}")
        return 1

    print("Current Transactions tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
