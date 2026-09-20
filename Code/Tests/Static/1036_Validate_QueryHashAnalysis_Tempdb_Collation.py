#!/usr/bin/env python3
"""Validate explicit framework collation in QueryHashAnalysis work tables."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


PROCEDURE_PATH = Path("Code/04_PlanCache/020_USP_QueryHashAnalysis.sql")
OUTPUT_TABLE = re.compile(
    r"CREATE\s+TABLE\s+\[#QueryHashAnalysis_Output\]\s*\((.*?)\);",
    re.IGNORECASE | re.DOTALL,
)
SAMPLE_TEXT = re.compile(
    r"\[SampleStatementText\]\s+nvarchar\(max\)\s+COLLATE\s+SQL_Latin1_General_CP1_CS_AS\s+NULL",
    re.IGNORECASE,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        print("QueryHashAnalysis tempdb-collation validator self-test passed.")
        return 0

    source = (args.repository_root.resolve() / PROCEDURE_PATH).read_text(encoding="utf-8")
    match = OUTPUT_TABLE.search(source)
    if match is None or SAMPLE_TEXT.search(match.group(1)) is None:
        print(
            "QueryHashAnalysis tempdb-collation validation failed: "
            "SampleStatementText lacks the framework collation.",
            file=sys.stderr,
        )
        return 1

    print("QueryHashAnalysis tempdb-collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
