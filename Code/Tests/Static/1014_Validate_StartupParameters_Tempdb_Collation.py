#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Startup Parameters procedure."""

from __future__ import annotations

import argparse
from pathlib import Path


PROCEDURE = "Code/08_ServerHealth/070_USP_StartupParameters.sql"
REQUIRED = (
    "[registry_key] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[value_name] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[value_data] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[ParameterType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS",
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
        assert len(REQUIRED) == 4
        assert all("COLLATE SQL_Latin1_General_CP1_CS_AS" in item for item in REQUIRED)
        print("Startup Parameters tempdb-collation validator self-test passed.")
        return 0

    missing = validate(args.repository_root)
    if missing:
        print("Startup Parameters tempdb-collation validation failed:")
        for fragment in missing:
            print(f"- Missing: {fragment}")
        return 1

    print("Startup Parameters tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
