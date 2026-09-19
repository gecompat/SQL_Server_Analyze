#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Server Configuration procedure."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/08_ServerHealth/050_USP_ServerConfiguration.sql"
REQUIRED = (
    "[name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[Finding] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[Interpretation] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 3 and all(REQUIRED)
        print("Server Configuration temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Server Configuration collation contract: {token}" for token in REQUIRED if token not in source]
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Server Configuration temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
