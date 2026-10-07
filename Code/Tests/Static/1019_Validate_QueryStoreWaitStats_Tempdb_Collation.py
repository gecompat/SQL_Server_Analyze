#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Query Store Wait Stats procedure."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


PROCEDURE = "Code/05_QueryStore/030_USP_QueryStoreWaitStats.sql"
REQUIRED = (
    "[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


FIELDS = ("QueryStoreDatabaseId", "QueryStoreDatabaseName", "QueryId", "PlanId", "QueryHash",
          "QueryPlanHash", "WaitCategory", "WaitCategoryDesc", "ExecutionTypeDesc", "FirstIntervalStartUtc",
          "LastIntervalEndUtc", "RecordedRows", "TotalQueryWaitTimeMs", "AverageRecordedQueryWaitTimeMs",
          "MaxQueryWaitTimeMs", "QuerySqlText", "SourceType", "SourceObject", "CapturedAtUtc", "EvidenceScope",
          "IsAggregated", "QuerySqlTextCharacters", "QuerySqlTextBytes", "QuerySqlTextIsTruncated", "EvidenceLimit")
TEXT_FIELDS = {"QueryStoreDatabaseName": "sysname", "WaitCategoryDesc": "nvarchar(128)",
               "ExecutionTypeDesc": "nvarchar(128)", "QuerySqlText": "nvarchar(max)", "SourceType": "varchar(32)",
               "SourceObject": "nvarchar(256)", "EvidenceScope": "varchar(40)", "EvidenceLimit": "nvarchar(1000)"}
NUMERIC_FILTER = "CONVERT(nvarchar(10),[ws].[wait_category]) COLLATE SQL_Latin1_General_CP1_CS_AS=@WaitCategory COLLATE SQL_Latin1_General_CP1_CS_AS"
DESCRIPTOR_FILTER = "[ws].[wait_category_desc]=@WaitCategory"


def validate_result_tables(source: str) -> list[str]:
    errors = []
    for table, count in (("#QueryStoreWaitStats_DatabaseCandidates", 5), ("#QueryStoreWaitStats_Errors", 3)):
        match = re.search(r"CREATE TABLE \[" + re.escape(table) + r"\]\((.*?)\);", source, re.S)
        if not match or match.group(1).count("COLLATE SQL_Latin1_General_CP1_CS_AS") != count:
            errors.append(f"auxiliary text collation count differs: {table}")
    for table in ("#QueryStoreWaitStats_Result", "#QueryStoreWaitStats_Export"):
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
        if ddl.count("COLLATE SQL_Latin1_General_CP1_CS_AS") != 8:
            errors.append(f"result text collation count differs: {table}")
    if NUMERIC_FILTER not in source or DESCRIPTOR_FILTER not in source:
        errors.append("numeric/descriptor category predicate differs")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and len(FIELDS) == 25 and len(TEXT_FIELDS) == 8
        source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
        assert not validate_result_tables(source)
        export_start = source.index("CREATE TABLE [#QueryStoreWaitStats_Export]")
        mutated = source[:export_start] + source[export_start:].replace(
            "[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS",
            "[QuerySqlText] nvarchar(max)", 1)
        assert validate_result_tables(mutated)
        assert validate_result_tables(source.replace(NUMERIC_FILTER, "CONVERT(nvarchar(10),[ws].[wait_category])=@WaitCategory", 1))
        assert validate_result_tables(source.replace(DESCRIPTOR_FILTER, "[ws].[wait_category_desc] COLLATE SQL_Latin1_General_CP1_CS_AS=@WaitCategory", 1))
        print("Query Store Wait Stats temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Query Store Wait Stats collation contract: {token}" for token in REQUIRED if token not in source]
    errors.extend(validate_result_tables(source))
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Query Store Wait Stats temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
