#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Query Store Hints procedure."""
from __future__ import annotations

import argparse
import re
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


FIELDS = ("QueryStoreDatabaseId", "QueryStoreDatabaseName", "QueryHintId", "QueryId",
          "ReplicaGroupId", "QueryHash", "QueryHintText", "LastQueryHintFailureReason",
          "LastQueryHintFailureReasonDesc", "QueryHintFailureCount", "Source", "SourceDesc",
          "QuerySqlText", "SourceType", "SourceObject", "CapturedAtUtc", "EvidenceScope",
          "IsCurrent", "QuerySqlTextCharacters", "QuerySqlTextBytes", "QuerySqlTextIsTruncated", "EvidenceLimit")
TEXT_FIELDS = {"QueryStoreDatabaseName": "sysname", "QueryHintText": "nvarchar(max)",
               "LastQueryHintFailureReasonDesc": "nvarchar(128)", "SourceDesc": "nvarchar(128)",
               "QuerySqlText": "nvarchar(max)", "SourceType": "varchar(32)",
               "SourceObject": "nvarchar(256)", "EvidenceScope": "varchar(40)", "EvidenceLimit": "nvarchar(1000)"}


def validate_result_tables(source: str) -> list[str]:
    errors = []
    for table in ("#QueryStoreHints_Result", "#QueryStoreHints_Export"):
        match = re.search(r"CREATE TABLE \[" + re.escape(table) + r"\]\((.*?)\);", source, re.S)
        if not match:
            errors.append(f"missing typed result table: {table}")
            continue
        ddl = match.group(1)
        names = tuple(re.findall(r"\[([^]]+)\]", ddl))
        if names != FIELDS:
            errors.append(f"result field order/count differs: {table}")
        for name, datatype in TEXT_FIELDS.items():
            if f"[{name}] {datatype} COLLATE SQL_Latin1_General_CP1_CS_AS" not in ddl:
                errors.append(f"missing result text collation: {table}.{name}")
        if ddl.count("COLLATE SQL_Latin1_General_CP1_CS_AS") != 9:
            errors.append(f"result text collation count differs: {table}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and len(FIELDS) == 22 and len(TEXT_FIELDS) == 9
        source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
        assert not validate_result_tables(source)
        export_start = source.index("CREATE TABLE [#QueryStoreHints_Export]")
        mutated = source[:export_start] + source[export_start:].replace(
            "[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS",
            "[QueryHintText] nvarchar(max)", 1)
        assert validate_result_tables(mutated)
        print("Query Store Hints temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Query Store Hints collation contract: {token}" for token in REQUIRED if token not in source]
    errors.extend(validate_result_tables(source))
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Query Store Hints temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
