#!/usr/bin/env python3
"""Validate typed dynamic-SQL parameters in central database candidate preparation."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/01_Common/083_USP_PrepareDatabaseCandidates.sql"
REQUIRED = (
    "N'@IncludeSystem bit'",
    "@IncludeSystem = @SystemdatenbankenEinbeziehen;",
    "N'@Pattern nvarchar(4000), @Flags varchar(8)'",
    "@Pattern = @PatternValue",
    "@Flags = @RegexFlags;",
)


def validate(root: Path) -> list[str]:
    source = (root / PROCEDURE).read_text(encoding="utf-8-sig")
    return [f"missing typed dynamic parameter contract: {token}" for token in REQUIRED if token not in source]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        assert len(REQUIRED) == 5 and all(REQUIRED)
        print("Database-candidate dynamic-parameter validator self-test passed.")
        return 0

    errors = validate(args.repository_root.resolve())
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Database-candidate dynamic-parameter contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
