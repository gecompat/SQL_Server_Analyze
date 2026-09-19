#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Plan Cache Health procedure."""

from __future__ import annotations

import argparse
from pathlib import Path


PROCEDURE = "Code/04_PlanCache/030_USP_PlanCacheHealth.sql"
REQUIRED = {
    "[CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS": 2,
    "[ObjectType] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS": 2,
    "[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL": 2,
    "[SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS": 1,
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
        assert len(REQUIRED) == 4
        assert sum(REQUIRED.values()) == 7
        assert all("COLLATE SQL_Latin1_General_CP1_CS_AS" in item for item in REQUIRED)
        print("Plan Cache Health tempdb-collation validator self-test passed.")
        return 0

    missing = validate(args.repository_root)
    if missing:
        print("Plan Cache Health tempdb-collation validation failed:")
        for fragment in missing:
            print(f"- Missing: {fragment}")
        return 1

    print("Plan Cache Health tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
