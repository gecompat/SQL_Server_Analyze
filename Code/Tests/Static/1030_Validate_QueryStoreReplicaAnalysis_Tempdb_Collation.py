#!/usr/bin/env python3
"""Validate explicit framework collations in Query Store Replica Analysis work tables."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys

PROCEDURE_PATH = Path("Code/05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql")
COLLATION = "SQL_Latin1_General_CP1_CS_AS"
TABLE_REQUIREMENTS = {
    "#QueryStoreReplicaAnalysis_ResultTableMap": 2,
    "#QueryStoreReplicaAnalysis_DatabaseCandidates": 5,
    "#QueryStoreReplicaAnalysis_CandidateWarnings": 3,
    "#QueryStoreReplicaAnalysis_Replicas": 8,
    "#QueryStoreReplicaAnalysis_RuntimeByReplica": 7,
    "#QueryStoreReplicaAnalysis_WaitsByReplica": 9,
    "#QueryStoreReplicaAnalysis_ForcingByReplica": 7,
    "#QueryStoreReplicaAnalysis_SourceStatus": 7,
    "#QueryStoreReplicaAnalysis_Warnings": 4,
    "#QueryStoreReplicaAnalysis_ModuleStatus": 3,
}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("Query Store Replica Analysis tempdb-collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE_PATH).read_text(encoding="utf-8")
    errors = []
    for table_name, expected_count in TABLE_REQUIREMENTS.items():
        match = re.search(rf"CREATE\s+TABLE\s+\[{re.escape(table_name)}\]\s*\((.*?)\);", source, re.I | re.S)
        if match is None:
            errors.append(f"Missing CREATE TABLE definition for {table_name}.")
            continue
        actual_count = len(re.findall(rf"\bCOLLATE\s+{COLLATION}\b", match.group(1), re.I))
        if actual_count != expected_count:
            errors.append(f"{table_name} declares {actual_count} explicit framework collations; expected {expected_count}.")
    if errors:
        print("Query Store Replica Analysis tempdb-collation validation failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print("Query Store Replica Analysis tempdb-collation validation passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
