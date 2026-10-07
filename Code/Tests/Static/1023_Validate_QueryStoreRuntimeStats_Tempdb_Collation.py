#!/usr/bin/env python3
"""Validate explicit temp-table collation in the Query Store Runtime Stats procedure."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


PROCEDURE = "Code/05_QueryStore/020_USP_QueryStoreRuntimeStats.sql"
REQUIRED = (
    "[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS",
    "[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS",
)


FIELDS = ('QueryStoreDatabaseId', 'QueryStoreDatabaseName', 'QueryId', 'PlanId', 'QueryHash', 'QueryPlanHash', 'ObjectId', 'ObjectName', 'ExecutionTypeDesc', 'FirstExecutionTimeUtc', 'LastExecutionTimeUtc', 'ExecutionCount', 'TotalDurationMs', 'AverageDurationMs', 'TotalCpuMs', 'AverageCpuMs', 'TotalLogicalReads', 'AverageLogicalReads', 'TotalLogicalWrites', 'AverageLogicalWrites', 'TotalPhysicalReads', 'TotalMemoryGrantKb', 'MaxMemoryGrantKb', 'TotalRowCount', 'TotalLogBytes', 'TotalTempdbKb', 'SourceType', 'SourceObject', 'CapturedAtUtc', 'EvidenceScope', 'QuerySqlTextCharacters', 'QuerySqlTextBytes', 'QuerySqlTextIsTruncated', 'QuerySqlText', 'QueryPlanStatus', 'QueryPlanCharacters', 'QueryPlanBytes', 'QueryPlan', 'QueryPlanTextFallback', 'EvidenceLimit')
TEXT_FIELDS = {'QueryStoreDatabaseName': 'sysname', 'ObjectName': 'nvarchar(517)', 'ExecutionTypeDesc': 'nvarchar(60)', 'SourceType': 'varchar(32)', 'SourceObject': 'nvarchar(256)', 'EvidenceScope': 'varchar(40)', 'QuerySqlText': 'nvarchar(max)', 'QueryPlanStatus': 'varchar(40)', 'QueryPlanTextFallback': 'nvarchar(max)', 'EvidenceLimit': 'nvarchar(1000)'}

ALIASES = ("LastExecutionTimeUtc", "ExecutionCount", "TotalDurationMs", "TotalCpuMs", "TotalLogicalReads", "TotalLogicalWrites", "MaxMemoryGrantKb", "TotalLogBytes", "TotalTempdbKb")
ORDER_GUARD = "CASE WHEN @Order=N'LastExecutionTimeUtc' THEN N'' ELSE N', [last_execution_time] DESC' END"


def validate_result_tables(source: str) -> list[str]:
    errors = []
    for table, count in (("#QueryStoreRuntimeStats_DatabaseCandidates", 5), ("#QueryStoreRuntimeStats_Errors", 3)):
        match = re.search(r"CREATE TABLE \[" + re.escape(table) + r"\]\s*\((.*?)\);", source, re.S)
        if not match or match.group(1).count("COLLATE SQL_Latin1_General_CP1_CS_AS") != count:
            errors.append(f"auxiliary text collation count differs: {table}")
    for table in ("#QueryStoreRuntimeStats_Result", "#QueryStoreRuntimeStats_Export"):
        match = re.search(r"CREATE TABLE \[" + re.escape(table) + r"\]\s*\((.*?)\);", source, re.S)
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
        if ddl.count("COLLATE SQL_Latin1_General_CP1_CS_AS") != 10:
            errors.append(f"result text collation count differs: {table}")
    local_projection = source.split("    SELECT TOP (@TopRows)", 1)[-1].split("    FROM [A]", 1)[0]
    projected_object_id = re.search(r"(?m)^[ \t]*,[ \t]*\[A\]\.\[object_id\][ \t]*\r?\n[ \t]*,[ \t]*CASE[ \t]+WHEN[ \t]+\[A\]\.\[object_id\]", local_projection)
    if not projected_object_id or any("AS [" + name + "]" not in local_projection for name in ALIASES):
        errors.append("local projection qualification/rank aliases differ")
    if ORDER_GUARD not in source:
        errors.append("LAST_EXECUTION duplicate-order guard differs")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(REQUIRED) == 7 and len(FIELDS) == 40 and len(TEXT_FIELDS) == 10
        source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
        assert not validate_result_tables(source)
        export_start = source.index("CREATE TABLE [#QueryStoreRuntimeStats_Export]")
        mutated = source[:export_start] + source[export_start:].replace(
            "[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS",
            "[QuerySqlText] nvarchar(max)", 1)
        assert validate_result_tables(mutated)
        for table in ("#QueryStoreRuntimeStats_Result", "#QueryStoreRuntimeStats_Export"):
            table_start = source.index("CREATE TABLE [" + table + "]")
            table_end = source.index(");", table_start) + 2
            for name, datatype in TEXT_FIELDS.items():
                mutation = source[:table_start] + source[table_start:table_end].replace(
                    f"[{name}] {datatype} COLLATE SQL_Latin1_General_CP1_CS_AS",
                    f"[{name}] {datatype}", 1) + source[table_end:]
                assert validate_result_tables(mutation)
        projection_line = "        , [A].[object_id]\n"
        assert source.count(projection_line) == 1
        unqualified_projection = source.replace(projection_line, "        , [object_id]\n", 1)
        assert "CASE WHEN [A].[object_id] > 0" in unqualified_projection
        assert validate_result_tables(unqualified_projection)
        for name in ALIASES:
            assert validate_result_tables(source.replace(" AS [" + name + "]", "", 1))
        assert validate_result_tables(source.replace(ORDER_GUARD, "N', [last_execution_time] DESC'", 1))
        print("Query Store Runtime Stats temp-table collation validator self-test passed.")
        return 0
    source = (args.repository_root.resolve() / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing Query Store Runtime Stats collation contract: {token}" for token in REQUIRED if token not in source]
    errors.extend(validate_result_tables(source))
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Query Store Runtime Stats temporary-table collation contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
