#!/usr/bin/env python3
"""Validate the existing typed, shared Query Store Status result contract."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

PROCEDURE_PATH = Path("Code/05_QueryStore/010_USP_QueryStoreStatus.sql")
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
FIELDS = (
    ("DatabaseId", "int", "NULL"), ("DatabaseName", "sysname", "NOT NULL"),
    ("DesiredState", "smallint", "NULL"), ("DesiredStateDesc", "nvarchar(60)", "NULL"),
    ("ActualState", "smallint", "NULL"), ("ActualStateDesc", "nvarchar(60)", "NULL"),
    ("ReadonlyReason", "int", "NULL"), ("CurrentStorageSizeMb", "bigint", "NULL"),
    ("MaxStorageSizeMb", "bigint", "NULL"), ("StorageUsedPercent", "decimal(9,2)", "NULL"),
    ("FlushIntervalSeconds", "bigint", "NULL"), ("IntervalLengthMinutes", "bigint", "NULL"),
    ("StaleQueryThresholdDays", "bigint", "NULL"), ("MaxPlansPerQuery", "bigint", "NULL"),
    ("QueryCaptureMode", "smallint", "NULL"), ("QueryCaptureModeDesc", "nvarchar(60)", "NULL"),
    ("SizeBasedCleanupMode", "smallint", "NULL"), ("SizeBasedCleanupModeDesc", "nvarchar(60)", "NULL"),
    ("WaitStatsCaptureMode", "smallint", "NULL"), ("WaitStatsCaptureModeDesc", "nvarchar(60)", "NULL"),
    ("CapturePolicyExecutionCount", "int", "NULL"), ("CapturePolicyTotalCompileCpuTimeMs", "bigint", "NULL"),
    ("CapturePolicyTotalExecutionCpuTimeMs", "bigint", "NULL"), ("CapturePolicyStaleThresholdHours", "int", "NULL"),
    ("IsEnabled", "bit", "NULL"), ("IsWritable", "bit", "NULL"), ("StatusHint", "nvarchar(1000)", "NULL"),
)
AUX_TEXTS = {
    "#QueryStoreStatus_DatabaseCandidates": {
        "DatabaseName": "sysname", "StateDesc": "nvarchar(60)", "UserAccessDesc": "nvarchar(60)",
        "CollationName": "sysname", "RecoveryModelDesc": "nvarchar(60)"},
    "#QueryStoreStatus_Errors": {
        "DatabaseName": "sysname", "StatusCode": "varchar(40)", "ErrorMessage": "nvarchar(2048)"},
}


def table_ddl(source: str, table: str) -> str | None:
    match = re.search(r"CREATE TABLE \[" + re.escape(table) + r"\]\s*\((.*?)\);", source, re.S)
    return match.group(1) if match else None


def validate_source(source: str) -> list[str]:
    failures = []
    table = "#QueryStoreStatus_Result"
    ddl = table_ddl(source, table)
    if ddl is None:
        failures.append(f"missing typed table {table}")
    else:
        if tuple(re.findall(r"\[([^]]+)\]", ddl)) != tuple(f[0] for f in FIELDS):
            failures.append("result fields or ordinals differ")
        for name, datatype, nullable in FIELDS:
            text = datatype.startswith(("nvarchar", "varchar")) or datatype == "sysname"
            expected = f"[{name}] {datatype}" + (f" {COLLATION}" if text else "") + f" {nullable}"
            actual = re.search(r"\[" + re.escape(name) + r"\]([^\n]+)", ddl)
            if actual is None or " ".join((f"[{name}]" + actual.group(1)).strip().split()) != expected:
                failures.append(f"result field contract differs: {name}")
        if ddl.count(COLLATION) != 7 or re.search(r"\bIDENTITY\b", ddl, re.I):
            failures.append("result text count or identity differs")
    for auxiliary, fields in AUX_TEXTS.items():
        work = table_ddl(source, auxiliary)
        if work is None:
            failures.append(f"missing typed table {auxiliary}")
            continue
        for name, datatype in fields.items():
            if not re.search(r"\[" + re.escape(name) + r"\]\s+" + re.escape(datatype) + r"\s+" + re.escape(COLLATION), work):
                failures.append(f"missing auxiliary text collation: {auxiliary}.{name}")
        if work.count(COLLATION) != len(fields):
            failures.append(f"auxiliary text count differs: {auxiliary}")
    if source.find("CREATE TABLE [#QueryStoreStatus_Result]") > source.find("EXEC [monitor].[USP_PrepareDatabaseCandidates]"):
        failures.append("result table must exist before candidate collection")
    if source.find("CREATE TABLE [#QueryStoreStatus_Result]") > source.find("SET LOCK_TIMEOUT 0"):
        failures.append("result table must exist before lock-timeout change")
    if len(re.findall(r"@SourceTable\s*=\s*N'#QueryStoreStatus_Result'", source)) != 2:
        failures.append("TABLE and active CONSOLE must use the existing shared result")
    if not re.search(r"SELECT \* FROM \[#QueryStoreStatus_Result\] ORDER BY \[DatabaseId\]\s+FOR JSON", source):
        failures.append("JSON must use the shared result")
    if not re.search(r"SELECT \* FROM \[#QueryStoreStatus_Result\] ORDER BY \[DatabaseId\];", source):
        failures.append("RAW must use the shared result")
    return failures


def validate(repository_root: Path) -> list[str]:
    return validate_source((repository_root / PROCEDURE_PATH).read_text(encoding="utf-8-sig"))


def self_test(source: str) -> None:
    assert not validate_source(source)
    mutations = 0
    for table, fields in {"#QueryStoreStatus_Result": dict((n, t) for n, t, _ in FIELDS if t.startswith("nvarchar") or t == "sysname"), **AUX_TEXTS}.items():
        ddl = table_ddl(source, table)
        assert ddl is not None
        for name, datatype in fields.items():
            needle = re.search(r"\[" + re.escape(name) + r"\]\s+" + re.escape(datatype) + r"\s+" + re.escape(COLLATION), ddl)
            assert needle is not None
            changed = ddl.replace(needle.group(), needle.group().replace(COLLATION, ""), 1)
            assert validate_source(source.replace(ddl, changed, 1)), (table, name)
            mutations += 1
    ddl = table_ddl(source, "#QueryStoreStatus_Result")
    assert ddl is not None
    for old, new in (("[DatabaseName] sysname " + COLLATION + " NOT NULL", "[DatabaseName] sysname " + COLLATION + " NULL"),
                     ("[DatabaseId] int NULL", "[DatabaseId] bigint NULL"),
                     ("[DatabaseId] int NULL", "[DatabaseId] int IDENTITY(1,1) NULL"),
                     ("[StatusHint]", "[ExampleChangedHint]")):
        assert old in ddl
        assert validate_source(source.replace(ddl, ddl.replace(old, new, 1), 1))
        mutations += 1
    for old in ("@SourceTable=N'#QueryStoreStatus_Result'", "@SourceTable = N'#QueryStoreStatus_Result'",
                "SELECT * FROM [#QueryStoreStatus_Result] ORDER BY [DatabaseId]\n             FOR JSON",
                "SELECT * FROM [#QueryStoreStatus_Result] ORDER BY [DatabaseId];"):
        assert old in source
        assert validate_source(source.replace(old, old.replace("#QueryStoreStatus_Result", "#ExampleDifferentResult"), 1))
        mutations += 1
    print(f"Query Store Status validator self-test passed ({mutations} mutations).")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    source = (args.repository_root / PROCEDURE_PATH).read_text(encoding="utf-8-sig")
    if args.self_test:
        self_test(source)
        return 0
    failures = validate_source(source)
    if failures:
        print("Query Store Status validation failed: " + "; ".join(failures))
        return 1
    print("Query Store Status typed/shared-result collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
