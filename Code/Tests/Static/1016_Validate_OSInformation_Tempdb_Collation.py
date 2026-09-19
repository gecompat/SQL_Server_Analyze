#!/usr/bin/env python3
"""Validate explicit temp-table collation in the OS Information procedure."""

from __future__ import annotations

import argparse
from pathlib import Path


PROCEDURE = "Code/08_ServerHealth/080_USP_OSInformation.sql"
REQUIRED = (
    "[SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[host_platform] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[host_distribution] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[host_release] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[host_service_pack_level] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[system_memory_state_desc] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[servicename] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[startup_type_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[status_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[service_account] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[instant_file_initialization_enabled] nvarchar(10) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


def validate(repository_root: Path) -> list[str]:
    source = (repository_root / PROCEDURE).read_text(encoding="utf-8-sig")
    return [fragment for fragment in REQUIRED if fragment not in source]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        assert len(REQUIRED) == 13
        assert all("COLLATE SQL_Latin1_General_CP1_CS_AS" in item for item in REQUIRED)
        print("OS Information tempdb-collation validator self-test passed.")
        return 0

    missing = validate(args.repository_root)
    if missing:
        print("OS Information tempdb-collation validation failed:")
        for fragment in missing:
            print(f"- Missing: {fragment}")
        return 1

    print("OS Information tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
